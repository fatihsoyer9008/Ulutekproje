import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_current_user
from app.core.database import Base, get_db_session
from app.main import app
from app.models import ExpenseSplitType, User
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository
from app.repositories.settlements import SettlementRepository


@pytest_asyncio.fixture
async def balance_summary_context():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )

    @event.listens_for(engine.sync_engine, "connect")
    def _enable_foreign_keys(dbapi_connection, _connection_record) -> None:
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
        user_a = User(email="balance-a@example.com", display_name="A")
        user_b = User(email="balance-b@example.com", display_name="B")
        session.add_all([user_a, user_b])
        await session.commit()

        groups = GroupRepository(session)
        expenses = GroupExpenseRepository(session)
        settlements = SettlementRepository(session)

        # Group 1: A pays 10000, split evenly -> A is owed 5000.
        group_one = await groups.create(
            name="Group One", created_by=user_a.id, currency="TRY"
        )
        await groups.add_member(group_id=group_one.id, user_id=user_b.id)
        await expenses.create(
            group_id=group_one.id,
            payer_user_id=user_a.id,
            title="Expense 1",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=10000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(user_a.id, 5000), (user_b.id, 5000)],
        )

        # Group 2: B pays 6000, split evenly -> A owes 3000.
        group_two = await groups.create(
            name="Group Two", created_by=user_b.id, currency="TRY"
        )
        await groups.add_member(group_id=group_two.id, user_id=user_a.id)
        await expenses.create(
            group_id=group_two.id,
            payer_user_id=user_b.id,
            title="Expense 2",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=6000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(user_a.id, 3000), (user_b.id, 3000)],
        )

        # Settlement in Group 1: B pays A back 1000 -> A's balance drops by 1000.
        await settlements.create(
            group_id=group_one.id,
            from_user_id=user_b.id,
            to_user_id=user_a.id,
            amount_in_minor=1000,
            currency="TRY",
            settled_at=datetime.now(UTC),
            note=None,
        )

        # Direct (friend) group: should be excluded entirely from the overall total.
        direct_group = await groups.create(
            name="A & B",
            created_by=user_a.id,
            currency="TRY",
            is_direct=True,
        )
        await groups.add_member(group_id=direct_group.id, user_id=user_b.id)
        await expenses.create(
            group_id=direct_group.id,
            payer_user_id=user_a.id,
            title="Direct expense",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=99999,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(user_a.id, 0), (user_b.id, 99999)],
        )

        # Archived group: should also be excluded.
        archived_group = await groups.create(
            name="Old trip", created_by=user_a.id, currency="TRY"
        )
        await groups.add_member(group_id=archived_group.id, user_id=user_b.id)
        await expenses.create(
            group_id=archived_group.id,
            payer_user_id=user_a.id,
            title="Old expense",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=50000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(user_a.id, 0), (user_b.id, 50000)],
        )
        archived_group.archived_at = datetime.now(UTC)
        await session.commit()

    current_user = {"value": user_a}

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_current_user() -> User:
        return current_user["value"]

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_current_user

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield {
            "client": client,
            "current_user": current_user,
            "user_a": user_a,
            "user_b": user_b,
        }

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_overall_balance_sums_non_direct_non_archived_groups(
    balance_summary_context,
) -> None:
    client: httpx.AsyncClient = balance_summary_context["client"]

    response = await client.get("/api/v1/me/balance-summary")

    assert response.status_code == 200
    # A: +5000 (Group One) - 3000 (Group Two) - 1000 (settlement) = +1000.
    # The direct group's 99999 and the archived group's 50000 must not count.
    assert response.json() == {
        "overall_balances": [
            {
                "currency": "TRY",
                "net_amount_in_minor": 1000,
                "status": "you_are_owed",
            }
        ]
    }


@pytest.mark.asyncio
async def test_overall_balance_is_empty_array_with_no_activity(
    balance_summary_context,
) -> None:
    client: httpx.AsyncClient = balance_summary_context["client"]
    context_user = balance_summary_context["current_user"]
    context_user["value"] = User(
        id=uuid.uuid4(),
        email="no-activity@example.com",
        display_name="No Activity",
    )

    response = await client.get("/api/v1/me/balance-summary")

    assert response.status_code == 200
    assert response.json() == {"overall_balances": []}


@pytest.mark.asyncio
async def test_overall_balance_requires_authentication() -> None:
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_db_session] = override_db
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            response = await client.get("/api/v1/me/balance-summary")

        assert response.status_code == 401
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()
