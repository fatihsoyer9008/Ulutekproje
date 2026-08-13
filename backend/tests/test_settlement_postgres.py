import asyncio
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.api.dependencies import (
    get_current_user,
    get_debt_summary_cache,
)
from app.core.database import get_db_session
from app.main import app
from app.models import (
    Group,
    GroupMember,
    GroupRole,
    Settlement,
    SettlementIdempotencyRecord,
    User,
)
from tests.postgres_support import postgres_test_database_url


class NoopDebtSummaryCache:
    def __init__(self) -> None:
        self.invalidated_group_ids: list[uuid.UUID] = []

    async def invalidate(self, group_id: uuid.UUID) -> None:
        self.invalidated_group_ids.append(group_id)


@pytest_asyncio.fixture
async def postgres_settlement_context():
    engine = create_async_engine(postgres_test_database_url())
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    owner = User(
        email=f"settlement-pg-owner-{uuid.uuid4()}@example.com",
        display_name="PostgreSQL Owner",
    )
    member = User(
        email=f"settlement-pg-member-{uuid.uuid4()}@example.com",
        display_name="PostgreSQL Member",
    )

    async with session_factory() as session:
        session.add_all([owner, member])
        await session.flush()

        group = Group(
            name="PostgreSQL Settlement Group",
            currency="TRY",
            created_by=owner.id,
        )
        session.add(group)
        await session.flush()

        session.add_all(
            [
                GroupMember(
                    group_id=group.id,
                    user_id=owner.id,
                    role=GroupRole.owner,
                ),
                GroupMember(
                    group_id=group.id,
                    user_id=member.id,
                    role=GroupRole.member,
                ),
            ]
        )
        await session.commit()

    cache = NoopDebtSummaryCache()

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_user() -> User:
        return owner

    async def override_cache() -> NoopDebtSummaryCache:
        return cache

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_user
    app.dependency_overrides[get_debt_summary_cache] = override_cache

    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            yield {
                "client": client,
                "session_factory": session_factory,
                "group": group,
                "owner": owner,
                "member": member,
                "cache": cache,
            }
    finally:
        app.dependency_overrides.clear()

        async with session_factory() as session:
            await session.execute(delete(Group).where(Group.id == group.id))
            await session.execute(
                delete(User).where(User.id.in_((owner.id, member.id)))
            )
            await session.commit()

        await engine.dispose()


def _payload(
    *,
    owner: User,
    member: User,
    amount_in_minor: int = 2_500,
) -> dict[str, object]:
    return {
        "from_user_id": str(owner.id),
        "to_user_id": str(member.id),
        "amount_in_minor": amount_in_minor,
        "currency": "TRY",
        "settled_at": "2026-08-13T09:00:00Z",
        "note": "PostgreSQL concurrency test",
    }


@pytest.mark.asyncio
async def test_concurrent_identical_requests_create_one_settlement(
    postgres_settlement_context,
) -> None:
    context = postgres_settlement_context
    url = f"/api/v1/groups/{context['group'].id}/settlements"
    headers = {"Idempotency-Key": "settlement-pg-same-0001"}
    payload = _payload(
        owner=context["owner"],
        member=context["member"],
    )

    responses = await asyncio.gather(
        context["client"].post(
            url,
            headers=headers,
            json=payload,
        ),
        context["client"].post(
            url,
            headers=headers,
            json=payload,
        ),
    )

    assert sorted(response.status_code for response in responses) == [
        200,
        201,
    ]
    assert responses[0].json() == responses[1].json()

    replay = next(response for response in responses if response.status_code == 200)
    assert replay.headers["idempotency-replayed"] == "true"

    async with context["session_factory"]() as session:
        settlement_count = await session.scalar(
            select(func.count(Settlement.id)).where(
                Settlement.group_id == context["group"].id
            )
        )
        idempotency_count = await session.scalar(
            select(func.count(SettlementIdempotencyRecord.id)).where(
                SettlementIdempotencyRecord.group_id == context["group"].id
            )
        )

    assert settlement_count == 1
    assert idempotency_count == 1


@pytest.mark.asyncio
async def test_concurrent_conflicting_requests_return_409(
    postgres_settlement_context,
) -> None:
    context = postgres_settlement_context
    url = f"/api/v1/groups/{context['group'].id}/settlements"
    headers = {"Idempotency-Key": "settlement-pg-conflict-0001"}

    responses = await asyncio.gather(
        context["client"].post(
            url,
            headers=headers,
            json=_payload(
                owner=context["owner"],
                member=context["member"],
                amount_in_minor=2_500,
            ),
        ),
        context["client"].post(
            url,
            headers=headers,
            json=_payload(
                owner=context["owner"],
                member=context["member"],
                amount_in_minor=2_501,
            ),
        ),
    )

    assert sorted(response.status_code for response in responses) == [
        201,
        409,
    ]
    conflict = next(response for response in responses if response.status_code == 409)
    assert conflict.json()["detail"]["code"] == "idempotency_conflict"


@pytest.mark.asyncio
async def test_archive_wins_before_settlement_validation(
    postgres_settlement_context,
) -> None:
    context = postgres_settlement_context

    async with context["session_factory"]() as blocker:
        group = await blocker.scalar(
            select(Group).where(Group.id == context["group"].id).with_for_update()
        )
        assert group is not None

        group.archived_at = datetime.now(UTC)
        await blocker.flush()

        request_task = asyncio.create_task(
            context["client"].post(
                f"/api/v1/groups/{group.id}/settlements",
                headers={"Idempotency-Key": "archive-race-0001"},
                json=_payload(
                    owner=context["owner"],
                    member=context["member"],
                ),
            )
        )

        with pytest.raises(TimeoutError):
            await asyncio.wait_for(
                asyncio.shield(request_task),
                timeout=0.2,
            )

        await blocker.commit()
        response = await request_task

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "group_forbidden"


@pytest.mark.asyncio
async def test_member_removal_wins_before_settlement_validation(
    postgres_settlement_context,
) -> None:
    context = postgres_settlement_context

    async with context["session_factory"]() as blocker:
        group = await blocker.scalar(
            select(Group).where(Group.id == context["group"].id).with_for_update()
        )
        assert group is not None

        membership = await blocker.get(
            GroupMember,
            (group.id, context["member"].id),
        )
        assert membership is not None

        membership.left_at = datetime.now(UTC)
        await blocker.flush()

        request_task = asyncio.create_task(
            context["client"].post(
                f"/api/v1/groups/{group.id}/settlements",
                headers={"Idempotency-Key": "member-race-0001"},
                json=_payload(
                    owner=context["owner"],
                    member=context["member"],
                ),
            )
        )

        with pytest.raises(TimeoutError):
            await asyncio.wait_for(
                asyncio.shield(request_task),
                timeout=0.2,
            )

        await blocker.commit()
        response = await request_task

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "member_not_found"


@pytest.mark.asyncio
async def test_postgres_enforces_settlement_constraints(
    postgres_settlement_context,
) -> None:
    context = postgres_settlement_context

    invalid_values = (
        {
            "from_user_id": context["owner"].id,
            "to_user_id": context["member"].id,
            "amount_in_minor": 0,
            "currency": "TRY",
        },
        {
            "from_user_id": context["owner"].id,
            "to_user_id": context["owner"].id,
            "amount_in_minor": 100,
            "currency": "TRY",
        },
        {
            "from_user_id": context["owner"].id,
            "to_user_id": context["member"].id,
            "amount_in_minor": 100,
            "currency": "try",
        },
    )

    async with context["session_factory"]() as session:
        for values in invalid_values:
            with pytest.raises(IntegrityError):
                async with session.begin_nested():
                    session.add(
                        Settlement(
                            group_id=context["group"].id,
                            from_user_id=values["from_user_id"],
                            to_user_id=values["to_user_id"],
                            amount_in_minor=values["amount_in_minor"],
                            currency=values["currency"],
                            settled_at=datetime.now(UTC),
                        )
                    )
                    await session.flush()
