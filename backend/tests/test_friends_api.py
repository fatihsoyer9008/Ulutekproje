import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

import httpx
import pytest
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db_session
from app.main import app
from app.models import ExpenseSplitType, GroupRole
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository
from app.repositories.settlements import SettlementRepository


@pytest.mark.asyncio
async def test_list_friends_is_empty_without_direct_groups(group_api_context) -> None:
    client, *_ = group_api_context

    response = await client.get("/api/v1/friends")

    assert response.status_code == 200
    assert response.json() == {"friends": []}


@pytest.mark.asyncio
async def test_list_friends_requires_authentication() -> None:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", poolclass=StaticPool)
    session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_db_session] = override_db
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/api/v1/friends")
        assert response.status_code == 401
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()


@pytest.mark.asyncio
async def test_list_friends_combines_direct_and_shared_group_balances(
    group_api_context,
) -> None:
    client, session_factory, _current, owner, member, outsider, _former = (
        group_api_context
    )

    async with session_factory() as session:
        groups = GroupRepository(session)
        expenses = GroupExpenseRepository(session)
        settlements = SettlementRepository(session)

        direct_group = await groups.create(
            name="", created_by=owner.id, currency="TRY", is_direct=True
        )
        await groups.add_member(
            group_id=direct_group.id, user_id=member.id, role=GroupRole.member
        )
        # Owner pays 10000, split evenly -> member owes owner 5000.
        await expenses.create(
            group_id=direct_group.id,
            payer_user_id=owner.id,
            title="Kahve",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=10_000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(owner.id, 5_000), (member.id, 5_000)],
        )
        # Member pays owner back 1000 -> owner's net drops to 4000.
        await settlements.create(
            group_id=direct_group.id,
            from_user_id=member.id,
            to_user_id=owner.id,
            amount_in_minor=1_000,
            currency="TRY",
            settled_at=datetime.now(UTC),
            note=None,
        )

        shared_group = await groups.create(
            name="Ev arkadaşları", created_by=owner.id, currency="TRY"
        )
        await groups.add_member(group_id=shared_group.id, user_id=member.id)
        await groups.add_member(group_id=shared_group.id, user_id=outsider.id)
        # Member pays 9000, split three ways -> owner owes member 3000 here.
        await expenses.create(
            group_id=shared_group.id,
            payer_user_id=member.id,
            title="Market",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=9_000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(owner.id, 3_000), (member.id, 3_000), (outsider.id, 3_000)],
        )

        # An unrelated group between owner and outsider only must not leak in.
        outsider_group = await groups.create(
            name="Owner & Outsider", created_by=owner.id, currency="TRY"
        )
        await groups.add_member(group_id=outsider_group.id, user_id=outsider.id)
        await expenses.create(
            group_id=outsider_group.id,
            payer_user_id=owner.id,
            title="Taksi",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=4_000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(owner.id, 2_000), (outsider.id, 2_000)],
        )

        await session.commit()

    response = await client.get("/api/v1/friends")

    assert response.status_code == 200
    body = response.json()
    assert len(body["friends"]) == 1
    friend = body["friends"][0]
    assert friend["user_id"] == str(member.id)
    assert friend["display_name"] == member.display_name
    assert friend["direct_group_id"] == str(direct_group.id)
    # 5000 (direct expense) - 1000 (settlement) - 3000 (shared group expense) = 1000.
    assert friend["net_amount_in_minor"] == 1_000
    assert friend["currency"] == "TRY"
    assert friend["status"] == "you_are_owed"
    assert friend["shared_group_ids"] == [str(shared_group.id)]


@pytest.mark.asyncio
async def test_create_friend_expense_creates_direct_group_once(
    group_api_context,
) -> None:
    client, session_factory, _current, owner, member, _outsider, _former = (
        group_api_context
    )

    payload = {
        "title": "Sinema",
        "expense_date": "2026-08-20T20:00:00Z",
        "total_amount_in_minor": 4_000,
        "currency": "TRY",
        "receipt_id": None,
        "payer_user_id": str(owner.id),
        "split": {"type": "equal", "member_ids": [str(owner.id), str(member.id)]},
    }

    first = await client.post(
        f"/api/v1/friends/{member.id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "cinema-1"},
    )
    assert first.status_code == 201
    direct_group_id = first.json()["expense"]["group_id"]

    second_payload = dict(payload, title="İkinci masraf")
    second = await client.post(
        f"/api/v1/friends/{member.id}/expenses",
        json=second_payload,
        headers={"Idempotency-Key": "cinema-2"},
    )
    assert second.status_code == 201
    assert second.json()["expense"]["group_id"] == direct_group_id

    async with session_factory() as session:
        direct_group = await GroupRepository(session).get_direct_group(
            owner.id, member.id
        )
    assert direct_group is not None
    assert str(direct_group.id) == direct_group_id

    friends_response = await client.get("/api/v1/friends")
    assert friends_response.status_code == 200
    friends = friends_response.json()["friends"]
    assert len(friends) == 1
    assert friends[0]["direct_group_id"] == direct_group_id


@pytest.mark.asyncio
async def test_create_friend_expense_accepts_receipt_draft_ocr_flow(
    group_api_context,
) -> None:
    client, _session_factory, _current, owner, member, _outsider, _former = (
        group_api_context
    )

    payload = {
        "title": "OCR market fişi",
        "note": "Friends OCR akışı",
        "expense_date": "2026-08-20T12:00:00Z",
        "total_amount_in_minor": 6_000,
        "currency": "TRY",
        "payer_user_id": str(owner.id),
        "receipt_draft": {
            "merchant_name": "Mahalle Market",
            "category": "Market",
            "line_items": [
                {
                    "position": 0,
                    "name": "Süt",
                    "quantity_milli": 1_000,
                    "unit_price_in_minor": 6_000,
                    "total_amount_in_minor": 6_000,
                }
            ],
        },
        "split": {
            "type": "itemized",
            "line_items": [
                {
                    "receipt_line_item_position": 0,
                    "shares": [
                        {
                            "user_id": str(owner.id),
                            "amount_in_minor": 3_000,
                            "quantity_share_milli": 500,
                        },
                        {
                            "user_id": str(member.id),
                            "amount_in_minor": 3_000,
                            "quantity_share_milli": 500,
                        },
                    ],
                }
            ],
        },
    }

    response = await client.post(
        f"/api/v1/friends/{member.id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "ocr-draft-1"},
    )

    assert response.status_code == 201
    expense = response.json()["expense"]
    assert expense["split_type"] == "itemized"
    assert len(expense["line_item_assignments"]) == 2
    assert sum(share["amount_in_minor"] for share in expense["shares"]) == 6_000


@pytest.mark.asyncio
async def test_create_friend_expense_rejects_self_and_unknown_user(
    group_api_context,
) -> None:
    client, _session_factory, _current, owner, _member, _outsider, _former = (
        group_api_context
    )

    payload = {
        "title": "Sinema",
        "expense_date": "2026-08-20T20:00:00Z",
        "total_amount_in_minor": 4_000,
        "currency": "TRY",
        "receipt_id": None,
        "payer_user_id": str(owner.id),
        "split": {"type": "equal", "member_ids": [str(owner.id)]},
    }

    self_response = await client.post(
        f"/api/v1/friends/{owner.id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "self-key-1"},
    )
    assert self_response.status_code == 422
    assert self_response.json()["detail"]["code"] == "cannot_friend_self"

    unknown_user_id = uuid.uuid4()
    unknown_response = await client.post(
        f"/api/v1/friends/{unknown_user_id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "unknown-1"},
    )
    assert unknown_response.status_code == 404
    assert unknown_response.json()["detail"]["code"] == "user_not_found"
