import uuid
from decimal import Decimal

import pytest

from app.models import GroupExpense
from app.repositories.groups import GroupRepository
from app.services.group_expense_service import (
    FastSplitValidationError,
    calculate_equal_shares,
    calculate_percentage_shares,
    validate_exact_shares,
)


def test_equal_split_distributes_pennies_by_stable_user_id() -> None:
    users = [uuid.UUID(int=3), uuid.UUID(int=1), uuid.UUID(int=2)]
    assert calculate_equal_shares(10_000, users) == [
        (uuid.UUID(int=1), 3_334),
        (uuid.UUID(int=2), 3_333),
        (uuid.UUID(int=3), 3_333),
    ]


def test_percentage_split_is_exact_and_deterministic() -> None:
    users = [uuid.UUID(int=2), uuid.UUID(int=1), uuid.UUID(int=3)]
    shares = calculate_percentage_shares(
        10_000,
        [(user, Decimal("33.33")) for user in users[:-1]]
        + [(users[-1], Decimal("33.34"))],
    )
    assert shares == [
        (uuid.UUID(int=1), 3_333),
        (uuid.UUID(int=2), 3_333),
        (uuid.UUID(int=3), 3_334),
    ]
    assert sum(amount for _, amount in shares) == 10_000


def test_percentage_and_exact_totals_are_validated() -> None:
    user = uuid.uuid4()
    with pytest.raises(FastSplitValidationError, match="percentage_total_must_be_100"):
        calculate_percentage_shares(100, [(user, Decimal("99.99"))])
    with pytest.raises(
        FastSplitValidationError, match="exact_total_must_match_expense"
    ):
        validate_exact_shares(100, [(user, 99)])


def test_exact_split_preserves_explicit_amounts_in_stable_order() -> None:
    first, second = uuid.UUID(int=1), uuid.UUID(int=2)
    assert validate_exact_shares(10_000, [(second, 6_667), (first, 3_333)]) == [
        (first, 3_333),
        (second, 6_667),
    ]


@pytest.mark.asyncio
async def test_endpoint_creates_once_and_replays_idempotency_key(
    group_api_context,
) -> None:
    client, session_factory, _, owner, member, _, _ = group_api_context
    async with session_factory() as session:
        group = await GroupRepository(session).create(name="Tatil", created_by=owner.id)
        await GroupRepository(session).add_member(group_id=group.id, user_id=member.id)
        await session.commit()
        group_id = group.id
    payload = {
        "title": "Akşam yemeği",
        "expense_date": "2026-08-12T20:00:00Z",
        "total_amount_in_minor": 10_000,
        "currency": "TRY",
        "paid_by_id": str(member.id),
        "split_type": "EQUAL",
        "participants": [{"user_id": str(member.id)}, {"user_id": str(owner.id)}],
    }
    first = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "dinner-1"},
    )
    replay = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "dinner-1"},
    )
    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.headers["idempotency-replayed"] == "true"
    assert first.json() == replay.json()
    assert (
        sum(item["amount_in_minor"] for item in first.json()["expense"]["shares"])
        == 10_000
    )
    async with session_factory() as session:
        assert len((await session.execute(GroupExpense.__table__.select())).all()) == 1

    conflicting_payload = {**payload, "title": "Farklı masraf"}
    conflict = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=conflicting_payload,
        headers={"Idempotency-Key": "dinner-1"},
    )
    assert conflict.status_code == 409
    assert conflict.json()["detail"]["code"] == "idempotency_key_reused"


@pytest.mark.asyncio
async def test_endpoint_rejects_outsider_and_invalid_splits(group_api_context) -> None:
    client, session_factory, current_user, owner, member, outsider, _ = (
        group_api_context
    )
    async with session_factory() as session:
        group = await GroupRepository(session).create(name="Ev", created_by=owner.id)
        await GroupRepository(session).add_member(group_id=group.id, user_id=member.id)
        await session.commit()
        group_id = group.id
    base = {
        "title": "Market",
        "expense_date": "2026-08-12T12:00:00Z",
        "total_amount_in_minor": 1_000,
        "paid_by_id": str(owner.id),
        "split_type": "PERCENTAGE",
    }
    outsider_response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            **base,
            "participants": [{"user_id": str(outsider.id), "percentage": "100"}],
        },
    )
    invalid_total = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            **base,
            "participants": [{"user_id": str(owner.id), "percentage": "99.99"}],
        },
    )
    invalid_type = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            **base,
            "split_type": "RANDOM",
            "participants": [{"user_id": str(owner.id)}],
        },
    )
    assert outsider_response.status_code == 422
    assert outsider_response.json()["detail"]["code"] == "member_not_found"
    assert invalid_total.status_code == 422
    assert invalid_total.json()["detail"]["code"] == "percentage_total_must_be_100"
    assert invalid_type.status_code == 422
    assert invalid_type.json()["detail"]["code"] == "invalid_request"

    current_user["value"] = outsider
    forbidden_actor = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            **base,
            "participants": [{"user_id": str(owner.id), "percentage": "100"}],
        },
    )
    assert forbidden_actor.status_code == 403
    assert forbidden_actor.json()["detail"]["code"] == "group_forbidden"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("split_type", "participants", "expected_amounts"),
    [
        ("PERCENTAGE", ("33.33", "66.67"), (3_333, 6_667)),
        ("EXACT", (3_333, 6_667), (3_333, 6_667)),
    ],
)
async def test_endpoint_creates_percentage_and_exact_expenses(
    group_api_context, split_type, participants, expected_amounts
) -> None:
    client, session_factory, _, owner, member, _, _ = group_api_context
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Paylaşım", created_by=owner.id)
        await repository.add_member(group_id=group.id, user_id=member.id)
        await session.commit()
        group_id = group.id
    share_field = "percentage" if split_type == "PERCENTAGE" else "amount_in_minor"
    response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            "title": "Ortak masraf",
            "expense_date": "2026-08-12T12:00:00Z",
            "total_amount_in_minor": 10_000,
            "paid_by_id": str(owner.id),
            "split_type": split_type,
            "participants": [
                {"user_id": str(owner.id), share_field: participants[0]},
                {"user_id": str(member.id), share_field: participants[1]},
            ],
        },
    )
    assert response.status_code == 201
    amounts = sorted(
        item["amount_in_minor"] for item in response.json()["expense"]["shares"]
    )
    assert amounts == sorted(expected_amounts)
    assert sum(amounts) == 10_000
