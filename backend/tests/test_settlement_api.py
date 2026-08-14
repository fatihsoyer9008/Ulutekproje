import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from typing import cast

import httpx
import pytest
import pytest_asyncio
from redis.asyncio import Redis
from redis.exceptions import RedisError
from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool

from app.api.dependencies import (
    get_current_user,
    get_debt_summary_cache,
)
from app.core.database import Base, get_db_session
from app.domain.debts import DebtSummary
from app.main import app
from app.models import (
    ExpenseSplitType,
    Settlement,
    SettlementIdempotencyRecord,
    User,
)
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository
from app.services.debt_summary_cache import (
    DebtSummaryCache,
    DebtSummaryCacheUnavailable,
)


class FakeDebtSummaryCache:
    def __init__(self) -> None:
        self.attempted_group_ids: list[uuid.UUID] = []
        self.invalidated_group_ids: list[uuid.UUID] = []
        self.failures_remaining = 0
        self.summaries: dict[uuid.UUID, DebtSummary] = {}
        self.get_calls: list[uuid.UUID] = []
        self.set_calls: list[uuid.UUID] = []

    async def get(self, group_id: uuid.UUID) -> DebtSummary | None:
        self.get_calls.append(group_id)
        return self.summaries.get(group_id)

    async def set(self, summary: DebtSummary) -> bool:
        group_id = uuid.UUID(summary.group_id)
        self.set_calls.append(group_id)
        self.summaries[group_id] = summary
        return True

    async def invalidate(self, group_id: uuid.UUID) -> None:
        self.attempted_group_ids.append(group_id)

        if self.failures_remaining > 0:
            self.failures_remaining -= 1
            raise DebtSummaryCacheUnavailable("Test cache invalidation failure")

        self.invalidated_group_ids.append(group_id)
        self.summaries.pop(group_id, None)


class UnavailableRedis:
    async def get(self, key: str) -> str | None:
        del key
        raise RedisError("redis unavailable")

    async def set(self, key: str, value: str, *, ex: int) -> bool:
        del key, value, ex
        raise RedisError("redis unavailable")


@pytest_asyncio.fixture
async def settlement_api_context():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )

    @event.listens_for(engine.sync_engine, "connect")
    def _enable_foreign_keys(
        dbapi_connection,
        _connection_record,
    ) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async with session_factory() as session:
        owner = User(
            email="settlement-owner@example.com",
            display_name="Settlement Owner",
        )
        member = User(
            email="settlement-member@example.com",
            display_name="Settlement Member",
        )
        outsider = User(
            email="settlement-outsider@example.com",
            display_name="Settlement Outsider",
        )
        former = User(
            email="settlement-former@example.com",
            display_name="Settlement Former",
        )
        session.add_all([owner, member, outsider, former])
        await session.commit()

        repository = GroupRepository(session)
        group = await repository.create(
            name="Settlement Test Group",
            created_by=owner.id,
            currency="TRY",
        )
        await repository.add_member(
            group_id=group.id,
            user_id=member.id,
        )
        await repository.add_member(
            group_id=group.id,
            user_id=former.id,
        )
        await repository.mark_member_left(
            group_id=group.id,
            user_id=former.id,
            left_at=datetime.now(UTC),
        )
        await session.commit()
        group_id = group.id

    current_user = {"value": owner}
    fake_cache = FakeDebtSummaryCache()

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_current_user() -> User:
        return current_user["value"]

    async def override_cache() -> FakeDebtSummaryCache:
        return fake_cache

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_current_user
    app.dependency_overrides[get_debt_summary_cache] = override_cache

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield {
            "client": client,
            "session_factory": session_factory,
            "current_user": current_user,
            "cache": fake_cache,
            "group_id": group_id,
            "owner": owner,
            "member": member,
            "outsider": outsider,
            "former": former,
        }

    app.dependency_overrides.clear()
    await engine.dispose()


def _payload(
    *,
    from_user_id: uuid.UUID,
    to_user_id: uuid.UUID,
    amount_in_minor: object = 2500,
    currency: str = "TRY",
) -> dict[str, object]:
    return {
        "from_user_id": str(from_user_id),
        "to_user_id": str(to_user_id),
        "amount_in_minor": amount_in_minor,
        "currency": currency,
        "settled_at": "2026-08-11T09:00:00Z",
        "note": "Havale ile ödendi",
    }


@pytest.mark.asyncio
async def test_create_settlement_persists_and_invalidates_cache(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers={"Idempotency-Key": "settlement-create-0001"},
        json=_payload(
            from_user_id=context["owner"].id,
            to_user_id=context["member"].id,
        ),
    )

    assert response.status_code == 201
    assert response.headers["cache-control"] == "no-store"
    data = response.json()["settlement"]
    assert data["group_id"] == str(context["group_id"])
    assert data["from_user_id"] == str(context["owner"].id)
    assert data["to_user_id"] == str(context["member"].id)
    assert data["amount_in_minor"] == 2500
    assert data["currency"] == "TRY"
    assert data["settled_at"] == "2026-08-11T09:00:00Z"
    assert data["created_at"].endswith("Z")
    assert context["cache"].invalidated_group_ids == [context["group_id"]]

    async with context["session_factory"]() as session:
        stored = await session.get(
            Settlement,
            uuid.UUID(data["id"]),
        )

    assert stored is not None
    assert stored.note == "Havale ile ödendi"


@pytest.mark.asyncio
async def test_settlement_idempotency_replays_and_rejects_conflict(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    url = f"/api/v1/groups/{context['group_id']}/settlements"
    headers = {"Idempotency-Key": "settlement-replay-0001"}
    payload = _payload(
        from_user_id=context["owner"].id,
        to_user_id=context["member"].id,
    )

    first = await context["client"].post(
        url,
        headers=headers,
        json=payload,
    )
    replay = await context["client"].post(
        url,
        headers=headers,
        json=payload,
    )
    conflict = await context["client"].post(
        url,
        headers=headers,
        json={**payload, "amount_in_minor": 2501},
    )

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.headers["idempotency-replayed"] == "true"
    assert replay.json() == first.json()
    assert conflict.status_code == 409
    assert conflict.json()["detail"]["code"] == ("idempotency_conflict")
    assert context["cache"].invalidated_group_ids == [
        context["group_id"],
        context["group_id"],
    ]

    async with context["session_factory"]() as session:
        settlement_count = await session.scalar(select(func.count(Settlement.id)))
        idempotency_count = await session.scalar(
            select(func.count(SettlementIdempotencyRecord.id))
        )

    assert settlement_count == 1
    assert idempotency_count == 1


@pytest.mark.asyncio
async def test_sender_must_match_authenticated_user(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers={"Idempotency-Key": "settlement-sender-0001"},
        json=_payload(
            from_user_id=context["member"].id,
            to_user_id=context["owner"].id,
        ),
    )

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "group_forbidden"


@pytest.mark.asyncio
async def test_member_cannot_pay_self(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers={"Idempotency-Key": "settlement-self-0001"},
        json=_payload(
            from_user_id=context["owner"].id,
            to_user_id=context["owner"].id,
        ),
    )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"


@pytest.mark.asyncio
@pytest.mark.parametrize("target_name", ["outsider", "former"])
async def test_recipient_must_be_an_active_group_member(
    settlement_api_context,
    target_name: str,
) -> None:
    context = settlement_api_context
    response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers={"Idempotency-Key": f"settlement-{target_name}-0001"},
        json=_payload(
            from_user_id=context["owner"].id,
            to_user_id=context[target_name].id,
        ),
    )

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "member_not_found"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "amount_in_minor",
    [0, -1, 12.5, "2500", True],
)
async def test_amount_must_be_a_positive_strict_minor_unit_integer(
    settlement_api_context,
    amount_in_minor: object,
) -> None:
    context = settlement_api_context
    response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers={"Idempotency-Key": "settlement-amount-0001"},
        json=_payload(
            from_user_id=context["owner"].id,
            to_user_id=context["member"].id,
            amount_in_minor=amount_in_minor,
        ),
    )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"


@pytest.mark.asyncio
async def test_settlement_currency_must_match_group_currency(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers={"Idempotency-Key": "settlement-currency-0001"},
        json=_payload(
            from_user_id=context["owner"].id,
            to_user_id=context["member"].id,
            currency="USD",
        ),
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "currency_mismatch"


@pytest.mark.asyncio
async def test_settlement_changes_live_debt_summary(
    settlement_api_context,
) -> None:
    context = settlement_api_context

    async with context["session_factory"]() as session:
        await GroupExpenseRepository(session).create(
            group_id=context["group_id"],
            payer_user_id=context["owner"].id,
            created_by_id=context["owner"].id,
            title="Debt summary integration expense",
            expense_date=datetime(2026, 8, 11, 8, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=(
                (context["owner"].id, 6_250),
                (context["member"].id, 6_250),
            ),
        )
        await session.commit()

    before_response = await context["client"].get(
        f"/api/v1/groups/{context['group_id']}/debts"
    )
    assert before_response.status_code == 200
    cached_before_response = await context["client"].get(
        f"/api/v1/groups/{context['group_id']}/debts"
    )
    assert cached_before_response.json() == before_response.json()
    assert context["cache"].get_calls == [
        context["group_id"],
        context["group_id"],
    ]
    assert context["cache"].set_calls == [context["group_id"]]

    before_balances = {
        item["user_id"]: item["net_amount_in_minor"]
        for item in before_response.json()["balances"]
    }
    assert before_balances == {
        str(context["owner"].id): 6_250,
        str(context["member"].id): -6_250,
    }

    context["current_user"]["value"] = context["member"]
    create_response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers={"Idempotency-Key": "debt-summary-integration-0001"},
        json=_payload(
            from_user_id=context["member"].id,
            to_user_id=context["owner"].id,
            amount_in_minor=2_500,
        ),
    )
    assert create_response.status_code == 201

    after_response = await context["client"].get(
        f"/api/v1/groups/{context['group_id']}/debts"
    )
    assert after_response.status_code == 200
    assert context["cache"].set_calls == [
        context["group_id"],
        context["group_id"],
    ]

    after_data = after_response.json()
    after_balances = {
        item["user_id"]: item["net_amount_in_minor"] for item in after_data["balances"]
    }
    assert after_balances == {
        str(context["owner"].id): 3_750,
        str(context["member"].id): -3_750,
    }
    assert after_data["suggested_transfers"] == [
        {
            "from_user_id": str(context["member"].id),
            "to_user_id": str(context["owner"].id),
            "amount_in_minor": 3_750,
        }
    ]

    list_response = await context["client"].get(
        f"/api/v1/groups/{context['group_id']}/settlements"
    )
    assert list_response.status_code == 200
    assert len(list_response.json()["settlements"]) == 1


@pytest.mark.asyncio
async def test_debt_summary_falls_back_when_redis_is_unavailable(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    unavailable_cache = DebtSummaryCache(
        cast(Redis, UnavailableRedis()),
        max_attempts=1,
        initial_delay_seconds=0,
    )

    async def override_unavailable_cache() -> DebtSummaryCache:
        return unavailable_cache

    app.dependency_overrides[get_debt_summary_cache] = override_unavailable_cache
    try:
        response = await context["client"].get(
            f"/api/v1/groups/{context['group_id']}/debt-summary"
        )
    finally:
        app.dependency_overrides[get_debt_summary_cache] = lambda: context["cache"]

    assert response.status_code == 200
    assert response.json()["group_id"] == str(context["group_id"])


@pytest.mark.asyncio
async def test_cache_failure_is_retried_by_idempotent_replay(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    context["cache"].failures_remaining = 1

    url = f"/api/v1/groups/{context['group_id']}/settlements"
    headers = {"Idempotency-Key": "cache-recovery-0001"}
    payload = _payload(
        from_user_id=context["owner"].id,
        to_user_id=context["member"].id,
    )

    first = await context["client"].post(
        url,
        headers=headers,
        json=payload,
    )
    assert first.status_code == 503
    assert first.json()["detail"]["code"] == ("cache_invalidation_pending")

    replay = await context["client"].post(
        url,
        headers=headers,
        json=payload,
    )
    assert replay.status_code == 200
    assert replay.headers["idempotency-replayed"] == "true"

    async with context["session_factory"]() as session:
        settlement_count = await session.scalar(select(func.count(Settlement.id)))
        idempotency_count = await session.scalar(
            select(func.count(SettlementIdempotencyRecord.id))
        )

    assert settlement_count == 1
    assert idempotency_count == 1
    assert context["cache"].attempted_group_ids == [
        context["group_id"],
        context["group_id"],
    ]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("headers", "payload_changes"),
    [
        ({}, {}),
        ({"Idempotency-Key": "short"}, {}),
        (
            {"Idempotency-Key": "naive-date-0001"},
            {"settled_at": "2026-08-11T09:00:00"},
        ),
        (
            {"Idempotency-Key": "long-note-0001"},
            {"note": "x" * 1001},
        ),
    ],
)
async def test_settlement_request_boundaries(
    settlement_api_context,
    headers: dict[str, str],
    payload_changes: dict[str, object],
) -> None:
    context = settlement_api_context
    payload = _payload(
        from_user_id=context["owner"].id,
        to_user_id=context["member"].id,
    )
    payload.update(payload_changes)

    response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers=headers,
        json=payload,
    )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"


@pytest.mark.asyncio
async def test_archived_group_rejects_settlement(
    settlement_api_context,
) -> None:
    context = settlement_api_context

    async with context["session_factory"]() as session:
        group = await GroupRepository(session).get_by_id(context["group_id"])
        assert group is not None
        group.archived_at = datetime.now(UTC)
        await session.commit()

    response = await context["client"].post(
        f"/api/v1/groups/{context['group_id']}/settlements",
        headers={"Idempotency-Key": "archived-group-0001"},
        json=_payload(
            from_user_id=context["owner"].id,
            to_user_id=context["member"].id,
        ),
    )

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "group_forbidden"


@pytest.mark.asyncio
async def test_settlement_requires_authentication(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    override = app.dependency_overrides.pop(get_current_user)

    try:
        response = await context["client"].post(
            f"/api/v1/groups/{context['group_id']}/settlements",
            headers={"Idempotency-Key": "unauthenticated-0001"},
            json=_payload(
                from_user_id=context["owner"].id,
                to_user_id=context["member"].id,
            ),
        )
    finally:
        app.dependency_overrides[get_current_user] = override

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "unauthorized"
