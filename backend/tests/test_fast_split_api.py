import uuid

import pytest
from sqlalchemy.exc import IntegrityError

from app.api.routers.groups import _is_idempotency_collision
from app.models import GroupExpense
from app.repositories.groups import GroupRepository
from app.services.group_expense_service import (
    FastSplitValidationError,
    calculate_equal_shares,
    calculate_percentage_shares,
    validate_exact_shares,
)


def test_equal_split_distributes_pennies_by_request_order() -> None:
    users = [uuid.UUID(int=3), uuid.UUID(int=1), uuid.UUID(int=2)]
    assert calculate_equal_shares(10_000, users) == [
        (uuid.UUID(int=3), 3_334),
        (uuid.UUID(int=1), 3_333),
        (uuid.UUID(int=2), 3_333),
    ]


def test_percentage_split_is_exact_and_deterministic() -> None:
    users = [uuid.UUID(int=2), uuid.UUID(int=1), uuid.UUID(int=3)]
    shares = calculate_percentage_shares(
        10_000,
        [(users[0], 3333), (users[1], 3333), (users[2], 3334)],
    )
    assert shares == [
        (uuid.UUID(int=2), 3_333),
        (uuid.UUID(int=1), 3_333),
        (uuid.UUID(int=3), 3_334),
    ]
    assert sum(amount for _, amount in shares) == 10_000


def test_percentage_and_exact_totals_are_validated() -> None:
    user = uuid.uuid4()
    with pytest.raises(FastSplitValidationError, match="percentage_total_must_be_100"):
        calculate_percentage_shares(100, [(user, 9999)])
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


def test_non_idempotency_integrity_error_is_not_masked() -> None:
    error = IntegrityError("INSERT", {}, Exception("unrelated check violation"))
    assert _is_idempotency_collision(error) is False


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
        "receipt_id": None,
        "payer_user_id": str(member.id),
        "split": {"type": "equal", "member_ids": [str(member.id), str(owner.id)]},
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
    expense = first.json()["expense"]
    assert expense["payer_user_id"] == str(member.id)
    assert expense["created_by"] == str(owner.id)
    assert expense["split_type"] == "equal"
    assert expense["receipt_id"] is None
    assert expense["is_financially_locked"] is False
    assert expense["line_item_assignments"] == []
    assert {share["display_name"] for share in expense["shares"]} == {
        "Grup Sahibi",
        "Grup Üyesi",
    }
    assert {share["status"] for share in expense["shares"]} == {"open"}
    assert {share["settled_at"] for share in expense["shares"]} == {None}
    assert all(share["expense_id"] == expense["id"] for share in expense["shares"])
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
    assert conflict.json()["detail"]["code"] == "idempotency_conflict"


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
        "payer_user_id": str(owner.id),
    }
    outsider_response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            **base,
            "split": {
                "type": "percentage",
                "shares": [
                    {"user_id": str(outsider.id), "percentage_basis_points": 10000}
                ],
            },
        },
        headers={"Idempotency-Key": "outsider-1"},
    )
    invalid_total = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            **base,
            "split": {
                "type": "percentage",
                "shares": [{"user_id": str(owner.id), "percentage_basis_points": 9999}],
            },
        },
        headers={"Idempotency-Key": "invalid-percent"},
    )
    invalid_type = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            **base,
            "split": {"type": "random", "member_ids": [str(owner.id)]},
        },
        headers={"Idempotency-Key": "invalid-type-1"},
    )
    assert outsider_response.status_code == 422
    assert outsider_response.json()["detail"]["code"] == "member_not_found"
    assert invalid_total.status_code == 422
    assert invalid_total.json()["detail"]["code"] == "invalid_percentage_total"
    assert invalid_type.status_code == 422
    assert invalid_type.json()["detail"]["code"] == "invalid_request"

    current_user["value"] = outsider
    forbidden_actor = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            **base,
            "split": {
                "type": "percentage",
                "shares": [
                    {"user_id": str(owner.id), "percentage_basis_points": 10000}
                ],
            },
        },
        headers={"Idempotency-Key": "forbidden-actor"},
    )
    assert forbidden_actor.status_code == 403
    assert forbidden_actor.json()["detail"]["code"] == "group_forbidden"


@pytest.mark.asyncio
@pytest.mark.parametrize("key", [None, "short", "x" * 129])
async def test_endpoint_requires_contract_idempotency_key(
    group_api_context, key
) -> None:
    client, session_factory, _, owner, _, _, _ = group_api_context
    async with session_factory() as session:
        group = await GroupRepository(session).create(
            name="Header", created_by=owner.id
        )
        await session.commit()
        group_id = group.id
    headers = {} if key is None else {"Idempotency-Key": key}
    response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            "payer_user_id": str(owner.id),
            "title": "Header check",
            "expense_date": "2026-08-12T12:00:00Z",
            "total_amount_in_minor": 100,
            "currency": "TRY",
            "split": {"type": "equal", "member_ids": [str(owner.id)]},
        },
        headers=headers,
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "invalid_request"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("split_type", "participants", "expected_amounts"),
    [
        ("percentage", (3333, 6667), (3_333, 6_667)),
        ("fixed_amount", (3_333, 6_667), (3_333, 6_667)),
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
    share_field = (
        "percentage_basis_points" if split_type == "percentage" else "amount_in_minor"
    )
    response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            "title": "Ortak masraf",
            "expense_date": "2026-08-12T12:00:00Z",
            "total_amount_in_minor": 10_000,
            "payer_user_id": str(owner.id),
            "split": {
                "type": split_type,
                "shares": [
                    {"user_id": str(owner.id), share_field: participants[0]},
                    {"user_id": str(member.id), share_field: participants[1]},
                ],
            },
        },
        headers={"Idempotency-Key": f"split-{split_type}"},
    )
    assert response.status_code == 201
    amounts = sorted(
        item["amount_in_minor"] for item in response.json()["expense"]["shares"]
    )
    assert amounts == sorted(expected_amounts)
    assert sum(amounts) == 10_000
