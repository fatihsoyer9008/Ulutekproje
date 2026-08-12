import uuid
from datetime import UTC, datetime
from decimal import Decimal

import pytest
from sqlalchemy import func, select

from app.models import CloudReceipt, CloudReceiptLineItem, GroupExpense
from app.repositories.groups import GroupRepository


async def _seed_itemized_context(
    session_factory,
    *,
    owner_id: uuid.UUID,
    member_id: uuid.UUID,
    with_line_items: bool = True,
) -> tuple[uuid.UUID, uuid.UUID, uuid.UUID | None, uuid.UUID | None]:
    async with session_factory() as session:
        groups = GroupRepository(session)
        group = await groups.create(name="Market Grubu", created_by=owner_id)
        await groups.add_member(group_id=group.id, user_id=member_id)

        now = datetime(2026, 8, 12, 12, 0, tzinfo=UTC)
        receipt = CloudReceipt(
            user_id=owner_id,
            client_record_id=uuid.uuid4(),
            installation_id_hash="a" * 64,
            total_amount_in_minor=12_500,
            currency="TRY",
            client_created_at=now,
            client_updated_at=now,
        )
        line_items: list[CloudReceiptLineItem] = []
        if with_line_items:
            line_items = [
                CloudReceiptLineItem(
                    client_record_id=uuid.uuid4(),
                    position=0,
                    name="Süt",
                    price_in_minor=6_000,
                    quantity=Decimal("2.000"),
                ),
                CloudReceiptLineItem(
                    client_record_id=uuid.uuid4(),
                    position=1,
                    name="Ekmek",
                    price_in_minor=6_000,
                    quantity=Decimal("1.000"),
                ),
            ]
            receipt.line_items.extend(line_items)
        session.add(receipt)
        await session.commit()
        line_item_ids = [item.id for item in line_items]
        return (
            group.id,
            receipt.id,
            line_item_ids[0] if line_item_ids else None,
            line_item_ids[1] if len(line_item_ids) > 1 else None,
        )


def _itemized_payload(
    *,
    owner_id: uuid.UUID,
    member_id: uuid.UUID,
    receipt_id: uuid.UUID,
    milk_id: uuid.UUID,
    bread_id: uuid.UUID,
) -> dict[str, object]:
    return {
        "title": "Market fişi",
        "note": "KDV ve servis farkı ayrıca paylaştırıldı",
        "expense_date": "2026-08-12T12:00:00Z",
        "total_amount_in_minor": 12_500,
        "currency": "TRY",
        "receipt_id": str(receipt_id),
        "payer_user_id": str(owner_id),
        "split": {
            "type": "itemized",
            "line_items": [
                {
                    "receipt_line_item_id": str(milk_id),
                    "shares": [
                        {
                            "user_id": str(owner_id),
                            "amount_in_minor": 3_000,
                            "quantity_share_milli": 1_000,
                        },
                        {
                            "user_id": str(member_id),
                            "amount_in_minor": 3_000,
                            "quantity_share_milli": 1_000,
                        },
                    ],
                },
                {
                    "receipt_line_item_id": str(bread_id),
                    "shares": [
                        {
                            "user_id": str(member_id),
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
                        {"user_id": str(owner_id), "amount_in_minor": 250},
                        {"user_id": str(member_id), "amount_in_minor": 250},
                    ],
                }
            ],
        },
    }


@pytest.mark.asyncio
async def test_itemized_endpoint_creates_multi_member_split_and_replays(
    group_api_context,
) -> None:
    client, session_factory, _, owner, member, _, _ = group_api_context
    group_id, receipt_id, milk_id, bread_id = await _seed_itemized_context(
        session_factory,
        owner_id=owner.id,
        member_id=member.id,
    )
    assert milk_id is not None and bread_id is not None
    payload = _itemized_payload(
        owner_id=owner.id,
        member_id=member.id,
        receipt_id=receipt_id,
        milk_id=milk_id,
        bread_id=bread_id,
    )

    first = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "itemized-market-1"},
    )
    replay = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "itemized-market-1"},
    )

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.headers["idempotency-replayed"] == "true"
    assert replay.json() == first.json()
    expense = first.json()["expense"]
    assert expense["split_type"] == "itemized"
    assert expense["receipt_id"] == str(receipt_id)
    assert len(expense["line_item_assignments"]) == 3
    assert {
        (item["receipt_line_item_id"], item["user_id"], item["amount_in_minor"])
        for item in expense["line_item_assignments"]
    } == {
        (str(milk_id), str(owner.id), 3_000),
        (str(milk_id), str(member.id), 3_000),
        (str(bread_id), str(member.id), 6_000),
    }
    assert {
        share["user_id"]: share["amount_in_minor"] for share in expense["shares"]
    } == {
        str(owner.id): 3_250,
        str(member.id): 9_250,
    }

    conflict = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={**payload, "title": "Farklı market fişi"},
        headers={"Idempotency-Key": "itemized-market-1"},
    )
    assert conflict.status_code == 409
    assert conflict.json()["detail"]["code"] == "idempotency_conflict"

    async with session_factory() as session:
        count = await session.scalar(select(func.count()).select_from(GroupExpense))
        assert count == 1


@pytest.mark.asyncio
async def test_itemized_endpoint_reports_unassigned_items_and_total_mismatch(
    group_api_context,
) -> None:
    client, session_factory, _, owner, member, _, _ = group_api_context
    group_id, receipt_id, milk_id, bread_id = await _seed_itemized_context(
        session_factory,
        owner_id=owner.id,
        member_id=member.id,
    )
    assert milk_id is not None and bread_id is not None
    payload = _itemized_payload(
        owner_id=owner.id,
        member_id=member.id,
        receipt_id=receipt_id,
        milk_id=milk_id,
        bread_id=bread_id,
    )

    only_milk = {
        **payload,
        "split": {
            **payload["split"],
            "line_items": payload["split"]["line_items"][:1],
        },
    }
    unassigned = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=only_milk,
        headers={"Idempotency-Key": "itemized-unassigned"},
    )
    assert unassigned.status_code == 422
    assert unassigned.json()["detail"]["code"] == "unassigned_line_items"
    assert unassigned.json()["detail"]["unassigned_receipt_line_item_ids"] == [
        str(bread_id)
    ]

    mismatched = _itemized_payload(
        owner_id=owner.id,
        member_id=member.id,
        receipt_id=receipt_id,
        milk_id=milk_id,
        bread_id=bread_id,
    )
    mismatched["split"]["line_items"][0]["shares"][0]["amount_in_minor"] = 2_999
    invalid_total = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=mismatched,
        headers={"Idempotency-Key": "itemized-bad-total"},
    )
    assert invalid_total.status_code == 422
    assert invalid_total.json()["detail"]["code"] == "invalid_split_total"

    async with session_factory() as session:
        count = await session.scalar(select(func.count()).select_from(GroupExpense))
        assert count == 0


@pytest.mark.asyncio
async def test_itemized_endpoint_rejects_itemless_receipt(
    group_api_context,
) -> None:
    client, session_factory, _, owner, member, _, _ = group_api_context
    group_id, receipt_id, _, _ = await _seed_itemized_context(
        session_factory,
        owner_id=owner.id,
        member_id=member.id,
        with_line_items=False,
    )
    response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            "title": "Kalemsiz dekont",
            "expense_date": "2026-08-12T12:00:00Z",
            "total_amount_in_minor": 12_500,
            "currency": "TRY",
            "receipt_id": str(receipt_id),
            "payer_user_id": str(owner.id),
            "split": {
                "type": "itemized",
                "line_items": [
                    {
                        "receipt_line_item_id": str(uuid.uuid4()),
                        "shares": [
                            {"user_id": str(owner.id), "amount_in_minor": 12_500}
                        ],
                    }
                ],
            },
        },
        headers={"Idempotency-Key": "itemless-receipt"},
    )
    assert response.status_code == 400
    detail = response.json()["detail"]
    assert detail["code"] == "invalid_request"
    assert detail["message"]


@pytest.mark.asyncio
async def test_itemized_endpoint_applies_membership_and_receipt_authorization(
    group_api_context,
) -> None:
    client, session_factory, current_user, owner, member, outsider, _ = (
        group_api_context
    )
    group_id, receipt_id, milk_id, bread_id = await _seed_itemized_context(
        session_factory,
        owner_id=owner.id,
        member_id=member.id,
    )
    assert milk_id is not None and bread_id is not None
    payload = _itemized_payload(
        owner_id=owner.id,
        member_id=member.id,
        receipt_id=receipt_id,
        milk_id=milk_id,
        bread_id=bread_id,
    )

    outsider_share = _itemized_payload(
        owner_id=owner.id,
        member_id=member.id,
        receipt_id=receipt_id,
        milk_id=milk_id,
        bread_id=bread_id,
    )
    outsider_share["split"]["line_items"][0]["shares"][0]["user_id"] = str(outsider.id)
    invalid_member = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=outsider_share,
        headers={"Idempotency-Key": "itemized-outsider-share"},
    )
    assert invalid_member.status_code == 404
    assert invalid_member.json()["detail"]["code"] == "member_not_found"

    current_user["value"] = outsider
    forbidden_actor = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "itemized-outsider-actor"},
    )
    assert forbidden_actor.status_code == 403
    assert forbidden_actor.json()["detail"]["code"] == "group_forbidden"


@pytest.mark.asyncio
async def test_itemized_request_schema_rejects_ambiguous_or_duplicate_assignments(
    group_api_context,
) -> None:
    client, session_factory, _, owner, member, _, _ = group_api_context
    group_id, receipt_id, milk_id, bread_id = await _seed_itemized_context(
        session_factory,
        owner_id=owner.id,
        member_id=member.id,
    )
    assert milk_id is not None and bread_id is not None
    payload = _itemized_payload(
        owner_id=owner.id,
        member_id=member.id,
        receipt_id=receipt_id,
        milk_id=milk_id,
        bread_id=bread_id,
    )
    payload["split"]["member_ids"] = [str(owner.id)]
    payload["split"]["line_items"][0]["shares"].append(
        {
            "user_id": str(owner.id),
            "amount_in_minor": 0,
            "quantity_share_milli": 1,
        }
    )

    response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json=payload,
        headers={"Idempotency-Key": "itemized-invalid-shape"},
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "invalid_request"
