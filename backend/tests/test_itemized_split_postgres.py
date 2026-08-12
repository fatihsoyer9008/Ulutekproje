import asyncio
import os
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from decimal import Decimal

import httpx
import pytest
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.api.dependencies import get_current_user
from app.core.database import get_db_session
from app.main import app
from app.models import (
    CloudReceipt,
    CloudReceiptLineItem,
    ExpenseLineItemAssignment,
    Group,
    GroupExpense,
    GroupMember,
    GroupRole,
    User,
)


@pytest.mark.asyncio
async def test_concurrent_itemized_retries_create_one_expense() -> None:
    database_url = os.getenv("POSTGRES_TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is required for PostgreSQL tests")
    engine = create_async_engine(database_url)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    owner = User(
        email=f"itemized-owner-{uuid.uuid4()}@example.com",
        display_name="Itemized Owner",
    )
    member = User(
        email=f"itemized-member-{uuid.uuid4()}@example.com",
        display_name="Itemized Member",
    )
    now = datetime(2026, 8, 12, 12, 0, tzinfo=UTC)

    async with session_factory() as session:
        session.add_all([owner, member])
        await session.flush()
        group = Group(name="Concurrent Itemized Split", created_by=owner.id)
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
        receipt = CloudReceipt(
            user_id=owner.id,
            client_record_id=uuid.uuid4(),
            installation_id_hash="b" * 64,
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

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_user() -> User:
        return owner

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_user
    payload = {
        "receipt_id": str(receipt.id),
        "payer_user_id": str(owner.id),
        "title": "Concurrent itemized expense",
        "note": None,
        "expense_date": "2026-08-12T12:00:00Z",
        "total_amount_in_minor": 12_500,
        "currency": "TRY",
        "split": {
            "type": "itemized",
            "line_items": [
                {
                    "receipt_line_item_id": str(milk.id),
                    "shares": [
                        {"user_id": str(owner.id), "amount_in_minor": 3_000},
                        {"user_id": str(member.id), "amount_in_minor": 3_000},
                    ],
                },
                {
                    "receipt_line_item_id": str(bread.id),
                    "shares": [{"user_id": str(member.id), "amount_in_minor": 6_000}],
                },
            ],
            "extra_amounts": [
                {
                    "type": "tax",
                    "label": "KDV",
                    "amount_in_minor": 500,
                    "shares": [
                        {"user_id": str(owner.id), "amount_in_minor": 250},
                        {"user_id": str(member.id), "amount_in_minor": 250},
                    ],
                }
            ],
        },
    }
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as client:
            responses = await asyncio.gather(
                *[
                    client.post(
                        f"/api/v1/groups/{group.id}/expenses",
                        json=payload,
                        headers={"Idempotency-Key": "concurrent-itemized-1"},
                    )
                    for _ in range(2)
                ]
            )
        assert sorted(response.status_code for response in responses) == [200, 201]
        assert responses[0].json() == responses[1].json()
        async with session_factory() as session:
            expense_count = await session.scalar(
                select(func.count())
                .select_from(GroupExpense)
                .where(GroupExpense.group_id == group.id)
            )
            assignment_count = await session.scalar(
                select(func.count())
                .select_from(ExpenseLineItemAssignment)
                .join(GroupExpense)
                .where(GroupExpense.group_id == group.id)
            )
            assert expense_count == 1
            assert assignment_count == 3
    finally:
        app.dependency_overrides.clear()
        async with session_factory() as session:
            await session.execute(delete(Group).where(Group.id == group.id))
            await session.execute(
                delete(User).where(User.id.in_((owner.id, member.id)))
            )
            await session.commit()
        await engine.dispose()
