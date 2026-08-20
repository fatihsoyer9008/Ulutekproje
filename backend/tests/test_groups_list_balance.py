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


@pytest_asyncio.fixture
async def groups_list_balance_context():
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
        user_a = User(email="list-a@example.com", display_name="A")
        user_b = User(email="list-b@example.com", display_name="B")
        session.add_all([user_a, user_b])
        await session.commit()

        groups = GroupRepository(session)
        expenses = GroupExpenseRepository(session)

        # Owes: A pays 10000, split evenly -> A is owed 5000.
        owed_group = await groups.create(
            name="Owed Group", created_by=user_a.id, currency="TRY"
        )
        await groups.add_member(group_id=owed_group.id, user_id=user_b.id)
        await expenses.create(
            group_id=owed_group.id,
            payer_user_id=user_a.id,
            title="Expense",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=10000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(user_a.id, 5000), (user_b.id, 5000)],
        )

        # Settled: A pays 1000, keeps the whole share -> net 0, but has activity.
        settled_group = await groups.create(
            name="Settled Group", created_by=user_a.id, currency="TRY"
        )
        await expenses.create(
            group_id=settled_group.id,
            payer_user_id=user_a.id,
            title="Solo expense",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=1000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(user_a.id, 1000)],
        )

        # No expenses at all.
        await groups.create(name="Empty Group", created_by=user_a.id, currency="TRY")

        # Direct (friend) group: must never appear in GET /groups.
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
        yield {"client": client, "user_a": user_a, "user_b": user_b}

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_groups_list_includes_balance_and_status(
    groups_list_balance_context,
) -> None:
    client: httpx.AsyncClient = groups_list_balance_context["client"]

    response = await client.get("/api/v1/groups")

    assert response.status_code == 200
    by_name = {group["name"]: group for group in response.json()["groups"]}

    # Direct groups are never listed here.
    assert "A & B" not in by_name
    assert len(by_name) == 3

    assert by_name["Owed Group"]["current_user_net_amount_in_minor"] == 5000
    assert by_name["Owed Group"]["status"] == "you_are_owed"

    assert by_name["Settled Group"]["current_user_net_amount_in_minor"] == 0
    assert by_name["Settled Group"]["status"] == "settled_up"

    assert by_name["Empty Group"]["current_user_net_amount_in_minor"] == 0
    assert by_name["Empty Group"]["status"] == "no_expenses"


@pytest.mark.asyncio
async def test_owed_group_appears_as_you_owe_for_the_other_member(
    groups_list_balance_context,
) -> None:
    client: httpx.AsyncClient = groups_list_balance_context["client"]
    context_user = groups_list_balance_context["user_b"]
    app.dependency_overrides[get_current_user] = lambda: context_user

    response = await client.get("/api/v1/groups")

    assert response.status_code == 200
    by_name = {group["name"]: group for group in response.json()["groups"]}
    assert by_name["Owed Group"]["current_user_net_amount_in_minor"] == -5000
    assert by_name["Owed Group"]["status"] == "you_owe"


@pytest.mark.asyncio
async def test_group_detail_also_reports_balance(
    groups_list_balance_context,
) -> None:
    client: httpx.AsyncClient = groups_list_balance_context["client"]

    list_response = await client.get("/api/v1/groups")
    owed_group_id = next(
        group["id"]
        for group in list_response.json()["groups"]
        if group["name"] == "Owed Group"
    )

    detail_response = await client.get(f"/api/v1/groups/{owed_group_id}")

    assert detail_response.status_code == 200
    detail = detail_response.json()["group"]
    assert detail["current_user_net_amount_in_minor"] == 5000
    assert detail["status"] == "you_are_owed"
