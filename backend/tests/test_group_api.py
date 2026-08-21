import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from decimal import Decimal

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_current_user, get_debt_summary_cache
from app.core.database import Base, get_db_session
from app.domain.debts import DebtSummary
from app.main import app
from app.models import (
    CloudReceipt,
    CloudReceiptLineItem,
    Group,
    GroupExpense,
    GroupMember,
    GroupRole,
    User,
)
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository


class FakeDebtSummaryCache:
    def __init__(self) -> None:
        self.summaries: dict[uuid.UUID, DebtSummary] = {}
        self.invalidated_group_ids: list[uuid.UUID] = []

    async def get(self, group_id: uuid.UUID) -> DebtSummary | None:
        return self.summaries.get(group_id)

    async def set(self, summary: DebtSummary) -> bool:
        self.summaries[uuid.UUID(summary.group_id)] = summary
        return True

    async def invalidate_best_effort(self, group_id: uuid.UUID) -> bool:
        self.invalidated_group_ids.append(group_id)
        self.summaries.pop(group_id, None)
        return True


@pytest_asyncio.fixture
async def group_api_context():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )

    @event.listens_for(engine.sync_engine, "connect")
    def _enable_sqlite_foreign_keys(dbapi_connection, _connection_record) -> None:
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
        owner = User(email="owner@example.com", display_name="Grup Sahibi")
        member = User(email="member@example.com", display_name="Grup Üyesi")
        outsider = User(email="outsider@example.com", display_name="Dış Kullanıcı")
        former = User(email="former@example.com", display_name="Eski Üye")
        session.add_all([owner, member, outsider, former])
        await session.commit()

    debt_cache = FakeDebtSummaryCache()
    current_user = {"value": owner, "debt_cache": debt_cache}

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_current_user() -> User:
        return current_user["value"]

    async def override_debt_cache() -> FakeDebtSummaryCache:
        return debt_cache

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_current_user
    app.dependency_overrides[get_debt_summary_cache] = override_debt_cache

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield (
            client,
            session_factory,
            current_user,
            owner,
            member,
            outsider,
            former,
        )

    app.dependency_overrides.clear()
    await engine.dispose()


async def _create_group(
    session_factory,
    *,
    owner_id: uuid.UUID,
    name: str,
) -> uuid.UUID:
    async with session_factory() as session:
        group = await GroupRepository(session).create(
            name=name,
            created_by=owner_id,
        )
        await session.commit()
        return group.id


def _assert_error(response: httpx.Response, *, status_code: int, code: str) -> None:
    assert response.status_code == status_code
    assert response.json()["detail"]["code"] == code
    assert response.json()["detail"]["message"]


@pytest.mark.asyncio
async def test_group_endpoints_require_authentication(group_api_context) -> None:
    client, _, _, _, _, _, _ = group_api_context
    override = app.dependency_overrides.pop(get_current_user)
    try:
        response = await client.get("/api/v1/groups")
    finally:
        app.dependency_overrides[get_current_user] = override

    _assert_error(response, status_code=401, code="unauthorized")
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.asyncio
async def test_create_group_adds_current_user_as_owner_atomically(
    group_api_context,
) -> None:
    client, session_factory, _, owner, _, _, _ = group_api_context

    response = await client.post(
        "/api/v1/groups",
        json={
            "name": "  Ev Arkadaşları  ",
            "description": "Ortak ev masrafları",
            "currency": "try",
        },
    )

    assert response.status_code == 201
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["pragma"] == "no-cache"
    group = response.json()["group"]
    assert group["name"] == "Ev Arkadaşları"
    assert group["description"] == "Ortak ev masrafları"
    assert group["currency"] == "TRY"
    assert group["member_count"] == 1
    assert group["current_user_role"] == "owner"
    assert group["created_by"] == str(owner.id)
    assert group["created_at"].endswith("Z")
    assert group["members"] == [
        {
            "group_id": group["id"],
            "user_id": str(owner.id),
            "display_name": "Grup Sahibi",
            "role": "owner",
            "joined_at": group["members"][0]["joined_at"],
            "left_at": None,
        }
    ]
    assert "email" not in group["members"][0]

    async with session_factory() as session:
        stored_group = await session.get(Group, uuid.UUID(group["id"]))
        stored_membership = await session.get(
            GroupMember,
            (uuid.UUID(group["id"]), owner.id),
        )
    assert stored_group is not None
    assert stored_membership is not None
    assert stored_membership.role is GroupRole.owner


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {"name": "Geçerli", "description": None},
        {"name": "   ", "currency": "TRY"},
        {"name": "Geçerli", "currency": "USD"},
        {"name": "Geçerli", "currency": "TRY", "unexpected": True},
        {"name": "Geçerli", "description": "x" * 1001, "currency": "TRY"},
    ],
)
async def test_create_group_uses_contract_validation_error(
    group_api_context,
    payload: dict[str, object],
) -> None:
    client, _, _, _, _, _, _ = group_api_context

    response = await client.post("/api/v1/groups", json=payload)

    _assert_error(response, status_code=400, code="invalid_request")


@pytest.mark.asyncio
async def test_list_groups_rejects_invalid_archive_filter(group_api_context) -> None:
    client, _, _, _, _, _, _ = group_api_context

    response = await client.get(
        "/api/v1/groups",
        params={"include_archived": "not-a-boolean"},
    )

    _assert_error(response, status_code=400, code="invalid_request")


@pytest.mark.asyncio
async def test_list_groups_returns_only_active_memberships_and_filters_archived(
    group_api_context,
) -> None:
    (
        client,
        session_factory,
        _,
        owner,
        member,
        outsider,
        former,
    ) = group_api_context
    async with session_factory() as session:
        repository = GroupRepository(session)
        active = await repository.create(name="Aktif Grup", created_by=owner.id)
        await repository.add_member(group_id=active.id, user_id=member.id)
        former_membership = await repository.add_member(
            group_id=active.id,
            user_id=former.id,
        )
        former_membership.left_at = datetime.now(UTC)

        archived = await repository.create(
            name="Arşivlenmiş Grup",
            created_by=owner.id,
        )
        archived.archived_at = datetime.now(UTC)
        await repository.create(name="Yabancı Grup", created_by=outsider.id)

        left_group = await repository.create(
            name="Ayrıldığım Grup",
            created_by=outsider.id,
        )
        left_membership = await repository.add_member(
            group_id=left_group.id,
            user_id=owner.id,
        )
        left_membership.left_at = datetime.now(UTC)
        await session.commit()

    active_response = await client.get("/api/v1/groups")
    archived_response = await client.get(
        "/api/v1/groups",
        params={"include_archived": "true"},
    )

    assert active_response.status_code == 200
    active_groups = active_response.json()["groups"]
    assert [group["name"] for group in active_groups] == ["Aktif Grup"]
    assert active_groups[0]["member_count"] == 2
    assert active_groups[0]["current_user_role"] == "owner"
    assert {group["name"] for group in archived_response.json()["groups"]} == {
        "Aktif Grup",
        "Arşivlenmiş Grup",
    }


@pytest.mark.asyncio
async def test_group_detail_requires_active_membership(group_api_context) -> None:
    client, session_factory, current_user, owner, member, outsider, former = (
        group_api_context
    )
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Detay Grubu", created_by=owner.id)
        await repository.add_member(group_id=group.id, user_id=member.id)
        departed = await repository.add_member(group_id=group.id, user_id=former.id)
        departed.left_at = datetime.now(UTC)
        await session.commit()
        group_id = group.id

    current_user["value"] = member
    member_response = await client.get(f"/api/v1/groups/{group_id}")
    assert member_response.status_code == 200
    detail = member_response.json()["group"]
    assert detail["current_user_role"] == "member"
    assert detail["member_count"] == 2
    assert {item["display_name"] for item in detail["members"]} == {
        "Grup Sahibi",
        "Grup Üyesi",
    }

    current_user["value"] = outsider
    forbidden = await client.get(f"/api/v1/groups/{group_id}")
    _assert_error(forbidden, status_code=403, code="group_forbidden")

    current_user["value"] = former
    departed_response = await client.get(f"/api/v1/groups/{group_id}")
    _assert_error(departed_response, status_code=403, code="group_forbidden")

    missing = await client.get(f"/api/v1/groups/{uuid.uuid4()}")
    _assert_error(missing, status_code=404, code="group_not_found")
    malformed = await client.get("/api/v1/groups/not-a-uuid")
    _assert_error(malformed, status_code=404, code="group_not_found")


@pytest.mark.asyncio
async def test_group_members_endpoint_returns_identity_role_and_departure(
    group_api_context,
) -> None:
    client, session_factory, _, owner, member, _, former = group_api_context
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Üye Sözleşmesi", created_by=owner.id)
        await repository.add_member(group_id=group.id, user_id=member.id)
        departed = await repository.add_member(group_id=group.id, user_id=former.id)
        departed.left_at = datetime.now(UTC)
        await session.commit()
        group_id = group.id

    response = await client.get(f"/api/v1/groups/{group_id}/members")

    assert response.status_code == 200
    members = response.json()["members"]
    assert len(members) == 3
    assert {
        (item["user_id"], item["name"], item["email"], item["role"]) for item in members
    } == {
        (str(owner.id), "Grup Sahibi", "owner@example.com", "owner"),
        (str(member.id), "Grup Üyesi", "member@example.com", "member"),
        (str(former.id), "Eski Üye", "former@example.com", "member"),
    }
    assert (
        next(item for item in members if item["user_id"] == str(former.id))["left_at"]
        is not None
    )


@pytest.mark.asyncio
async def test_group_members_endpoint_forbids_non_members(
    group_api_context,
) -> None:
    client, session_factory, current_user, owner, member, outsider, former = (
        group_api_context
    )
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Üye Yetki Testi", created_by=owner.id)
        await repository.add_member(group_id=group.id, user_id=member.id)
        departed = await repository.add_member(group_id=group.id, user_id=former.id)
        departed.left_at = datetime.now(UTC)
        await session.commit()
        group_id = group.id

    current_user["value"] = outsider
    forbidden = await client.get(f"/api/v1/groups/{group_id}/members")
    _assert_error(forbidden, status_code=403, code="group_forbidden")

    current_user["value"] = former
    departed_response = await client.get(f"/api/v1/groups/{group_id}/members")
    _assert_error(departed_response, status_code=403, code="group_forbidden")


@pytest.mark.asyncio
async def test_only_owner_can_update_group_and_clear_description(
    group_api_context,
) -> None:
    client, session_factory, current_user, owner, member, admin, _ = group_api_context
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(
            name="Eski Ad",
            description="Silinecek açıklama",
            created_by=owner.id,
        )
        await repository.add_member(group_id=group.id, user_id=member.id)
        await repository.add_member(
            group_id=group.id,
            user_id=admin.id,
            role=GroupRole.admin,
        )
        await session.commit()
        group_id = group.id

    for unauthorized_user in (member, admin):
        current_user["value"] = unauthorized_user
        forbidden = await client.patch(
            f"/api/v1/groups/{group_id}",
            json={"name": "Yetkisiz Değişiklik"},
        )
        _assert_error(forbidden, status_code=403, code="group_forbidden")

    current_user["value"] = owner
    updated = await client.patch(
        f"/api/v1/groups/{group_id}",
        json={"name": "  Yeni Ad  ", "description": None},
    )
    assert updated.status_code == 200
    detail = updated.json()["group"]
    assert detail["name"] == "Yeni Ad"
    assert detail["description"] is None
    assert detail["current_user_role"] == "owner"
    assert len(detail["members"]) == 3

    async with session_factory() as session:
        stored = await session.get(Group, group_id)
    assert stored is not None
    assert stored.name == "Yeni Ad"
    assert stored.description is None


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"name": None},
        {"name": "   "},
        {"description": "x" * 1001},
        {"currency": "TRY"},
    ],
)
async def test_update_group_rejects_invalid_payloads(
    group_api_context,
    payload: dict[str, object],
) -> None:
    client, session_factory, _, owner, _, _, _ = group_api_context
    group_id = await _create_group(
        session_factory,
        owner_id=owner.id,
        name="Değişmeyecek Grup",
    )

    response = await client.patch(f"/api/v1/groups/{group_id}", json=payload)

    _assert_error(response, status_code=400, code="invalid_request")


@pytest.mark.asyncio
async def test_archive_is_owner_only_soft_and_idempotent(group_api_context) -> None:
    client, session_factory, current_user, owner, member, _, _ = group_api_context
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Arşivlenecek", created_by=owner.id)
        await repository.add_member(group_id=group.id, user_id=member.id)
        await session.commit()
        group_id = group.id

    current_user["value"] = member
    forbidden = await client.delete(f"/api/v1/groups/{group_id}")
    _assert_error(forbidden, status_code=403, code="group_forbidden")

    current_user["value"] = owner
    archived = await client.delete(f"/api/v1/groups/{group_id}")
    assert archived.status_code == 204
    assert archived.content == b""

    async with session_factory() as session:
        stored = await session.get(Group, group_id)
        assert stored is not None
        first_archived_at = stored.archived_at
        assert first_archived_at is not None

    active_list = await client.get("/api/v1/groups")
    archived_list = await client.get(
        "/api/v1/groups",
        params={"include_archived": "true"},
    )
    assert active_list.json() == {"groups": []}
    assert [item["id"] for item in archived_list.json()["groups"]] == [str(group_id)]

    repeated = await client.delete(f"/api/v1/groups/{group_id}")
    assert repeated.status_code == 204
    async with session_factory() as session:
        stored = await session.get(Group, group_id)
        assert stored is not None
        assert stored.archived_at == first_archived_at


@pytest.mark.asyncio
async def test_archive_rejects_group_with_unsettled_balances(
    group_api_context,
) -> None:
    client, session_factory, _, owner, member, _, _ = group_api_context
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Borçlu Grup", created_by=owner.id)
        await repository.add_member(group_id=group.id, user_id=member.id)
        await session.commit()
        group_id = group.id

    expense = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers={"Idempotency-Key": "archive-unsettled-0001"},
        json={
            "receipt_id": None,
            "payer_user_id": str(owner.id),
            "title": "Ortak market",
            "note": None,
            "expense_date": "2026-08-21T10:00:00Z",
            "total_amount_in_minor": 10_000,
            "currency": "TRY",
            "split": {
                "type": "equal",
                "member_ids": [str(owner.id), str(member.id)],
            },
        },
    )
    assert expense.status_code == 201

    response = await client.delete(f"/api/v1/groups/{group_id}")

    _assert_error(
        response,
        status_code=409,
        code="group_has_unsettled_balances",
    )


@pytest.mark.asyncio
async def test_itemized_expense_reports_unassigned_line_item_ids(
    group_api_context,
) -> None:
    (
        client,
        session_factory,
        _current_user,
        owner,
        _member,
        _outsider,
        _former,
    ) = group_api_context

    group_id = await _create_group(
        session_factory,
        owner_id=owner.id,
        name="Itemized API Grubu",
    )

    async with session_factory() as session:
        now = datetime(2026, 8, 12, 10, 0, tzinfo=UTC)
        receipt = CloudReceipt(
            user_id=owner.id,
            client_record_id=uuid.uuid4(),
            installation_id_hash="b" * 64,
            total_amount_in_minor=12_500,
            client_created_at=now,
            client_updated_at=now,
        )
        milk = CloudReceiptLineItem(
            client_record_id=uuid.uuid4(),
            position=0,
            name="Süt",
            price_in_minor=6_000,
            quantity=Decimal("1.000"),
        )
        bread = CloudReceiptLineItem(
            client_record_id=uuid.uuid4(),
            position=1,
            name="Ekmek",
            price_in_minor=6_000,
            quantity=Decimal("1.000"),
        )
        receipt.line_items.extend([milk, bread])
        session.add(receipt)
        await session.commit()
        receipt_id = receipt.id
        milk_id = milk.id
        bread_id = bread.id

    response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers={"Idempotency-Key": "unassigned-items-0001"},
        json={
            "receipt_id": str(receipt_id),
            "payer_user_id": str(owner.id),
            "title": "Eksik ürünlü masraf",
            "note": None,
            "expense_date": "2026-08-12T10:00:00Z",
            "total_amount_in_minor": 6500,
            "currency": "TRY",
            "split": {
                "type": "itemized",
                "line_items": [
                    {
                        "receipt_line_item_id": str(milk_id),
                        "shares": [
                            {
                                "user_id": str(owner.id),
                                "amount_in_minor": 6000,
                                "quantity_share_milli": 1000,
                            }
                        ],
                    }
                ],
                "extra_amounts": [
                    {
                        "type": "tax",
                        "label": "KDV",
                        "amount_in_minor": 500,
                        "shares": [
                            {
                                "user_id": str(owner.id),
                                "amount_in_minor": 500,
                            }
                        ],
                    }
                ],
            },
        },
    )

    assert response.status_code == 422
    assert response.json()["detail"] == {
        "code": "unassigned_line_items",
        "message": "Atanmayan fiş ürünleri bulunuyor.",
        "unassigned_receipt_line_item_ids": [str(bread_id)],
    }


@pytest.mark.asyncio
async def test_itemized_expense_is_created_and_idempotently_replayed(
    group_api_context,
) -> None:
    (
        client,
        session_factory,
        _current_user,
        owner,
        member,
        _outsider,
        _former,
    ) = group_api_context

    async with session_factory() as session:
        group_repository = GroupRepository(session)
        group = await group_repository.create(
            name="Idempotent Itemized Grubu",
            created_by=owner.id,
        )
        await group_repository.add_member(
            group_id=group.id,
            user_id=member.id,
        )

        now = datetime(2026, 8, 12, 11, 0, tzinfo=UTC)
        receipt = CloudReceipt(
            user_id=owner.id,
            client_record_id=uuid.uuid4(),
            installation_id_hash="c" * 64,
            total_amount_in_minor=12_500,
            currency="TRY",
            client_created_at=now,
            client_updated_at=now,
        )
        milk = CloudReceiptLineItem(
            client_record_id=uuid.uuid4(),
            position=0,
            name="Süt",
            price_in_minor=6_000,
            quantity=Decimal("2.000"),
        )
        bread = CloudReceiptLineItem(
            client_record_id=uuid.uuid4(),
            position=1,
            name="Ekmek",
            price_in_minor=6_000,
            quantity=Decimal("1.000"),
        )
        receipt.line_items.extend([milk, bread])
        session.add(receipt)
        await session.commit()

        group_id = group.id
        receipt_id = receipt.id
        milk_id = milk.id
        bread_id = bread.id

    payload = {
        "receipt_id": str(receipt_id),
        "payer_user_id": str(owner.id),
        "title": "Market fişi",
        "note": None,
        "expense_date": "2026-08-12T11:00:00Z",
        "total_amount_in_minor": 12_500,
        "currency": "TRY",
        "split": {
            "type": "itemized",
            "line_items": [
                {
                    "receipt_line_item_id": str(milk_id),
                    "shares": [
                        {
                            "user_id": str(owner.id),
                            "amount_in_minor": 3_000,
                            "quantity_share_milli": 1_000,
                        },
                        {
                            "user_id": str(member.id),
                            "amount_in_minor": 3_000,
                            "quantity_share_milli": 1_000,
                        },
                    ],
                },
                {
                    "receipt_line_item_id": str(bread_id),
                    "shares": [
                        {
                            "user_id": str(member.id),
                            "amount_in_minor": 6_000,
                            "quantity_share_milli": 1_000,
                        }
                    ],
                },
            ],
            "extra_amounts": [
                {
                    "type": "tax",
                    "label": "KDV",
                    "amount_in_minor": 500,
                    "shares": [
                        {
                            "user_id": str(owner.id),
                            "amount_in_minor": 250,
                        },
                        {
                            "user_id": str(member.id),
                            "amount_in_minor": 250,
                        },
                    ],
                }
            ],
        },
    }
    headers = {"Idempotency-Key": "itemized-create-0001"}

    first = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers=headers,
        json=payload,
    )

    assert first.status_code == 201
    expense_data = first.json()["expense"]
    assert expense_data["group_id"] == str(group_id)
    assert expense_data["receipt_id"] == str(receipt_id)
    assert expense_data["created_by"] == str(owner.id)
    assert expense_data["split_type"] == "itemized"
    assert expense_data["is_financially_locked"] is False
    assert {share["display_name"] for share in expense_data["shares"]} == {
        "Grup Sahibi",
        "Grup Üyesi",
    }

    assert len(expense_data["extra_amounts"]) == 1
    extra_amount = expense_data["extra_amounts"][0]
    assert extra_amount["type"] == "tax"
    assert extra_amount["label"] == "KDV"
    assert extra_amount["amount_in_minor"] == 500
    assert {share["extra_amount_id"] for share in extra_amount["shares"]} == {
        extra_amount["id"]
    }

    replay = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers=headers,
        json=payload,
    )
    assert replay.status_code == 200
    assert replay.headers["idempotency-replayed"] == "true"
    assert expense_data["expense_date"] == "2026-08-12T11:00:00Z"
    assert replay.json()["expense"]["expense_date"] == ("2026-08-12T11:00:00Z")
    assert replay.json() == first.json()

    conflicting_payload = {
        **payload,
        "title": "Aynı anahtarla farklı masraf",
    }
    conflict = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers=headers,
        json=conflicting_payload,
    )
    assert conflict.status_code == 409
    assert conflict.json()["detail"]["code"] == "idempotency_conflict"

    cross_contract_payload = {
        "title": "Aynı anahtarla Fast Split",
        "expense_date": "2026-08-12T11:00:00Z",
        "total_amount_in_minor": 10_000,
        "currency": "TRY",
        "receipt_id": None,
        "payer_user_id": str(owner.id),
        "split": {
            "type": "equal",
            "member_ids": [
                str(owner.id),
                str(member.id),
            ],
        },
    }
    cross_contract_conflict = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers=headers,
        json=cross_contract_payload,
    )

    assert cross_contract_conflict.status_code == 409
    assert cross_contract_conflict.json()["detail"]["code"] == "idempotency_conflict"

    async with session_factory() as session:
        stored_member = await session.get(User, member.id)
        assert stored_member is not None
        await session.delete(stored_member)
        await session.commit()

    replay_after_member_deletion = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers=headers,
        json=payload,
    )
    assert replay_after_member_deletion.status_code == 200
    assert replay_after_member_deletion.headers["idempotency-replayed"] == "true"
    assert {
        share["display_name"]
        for share in replay_after_member_deletion.json()["expense"]["shares"]
    } == {
        "Grup Sahibi",
        "Silinmiş kullanıcı",
    }

    expense_id = uuid.UUID(expense_data["id"])
    async with session_factory() as session:
        expense_count = await session.scalar(
            select(func.count(GroupExpense.id)).where(GroupExpense.group_id == group_id)
        )
        stored = await GroupExpenseRepository(session).get_by_id(expense_id)

    assert expense_count == 1
    assert stored is not None
    assert stored.created_by == owner.id
    assert len(stored.line_item_assignments) == 3
    assert len(stored.extra_amounts) == 1
    assert stored.extra_amounts[0].amount_in_minor == 500
    assert len(stored.extra_amounts[0].shares) == 2
