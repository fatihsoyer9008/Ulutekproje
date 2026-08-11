import uuid
from collections.abc import AsyncIterator, Sequence
from datetime import UTC, datetime

import pytest
import pytest_asyncio
from sqlalchemy import event
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import ExpenseShareStatus, ExpenseSplitType, Group, User
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository


@pytest_asyncio.fixture
async def repository_context() -> (
    AsyncIterator[tuple[AsyncSession, GroupExpenseRepository, Group, User, User]]
):
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
        owner = User(email="expense-owner@example.com")
        member = User(email="expense-member@example.com")
        session.add_all([owner, member])
        await session.flush()

        groups = GroupRepository(session)
        group = await groups.create(
            name="Masraf Test Grubu",
            created_by=owner.id,
        )
        await groups.add_member(
            group_id=group.id,
            user_id=member.id,
        )
        await session.commit()

        yield (
            session,
            GroupExpenseRepository(session),
            group,
            owner,
            member,
        )

    await engine.dispose()


async def _create_expense(
    repository: GroupExpenseRepository,
    *,
    group: Group,
    owner: User,
    member: User,
    total_amount_in_minor: int = 12_500,
    shares: Sequence[tuple[uuid.UUID, int]] | None = None,
):
    return await repository.create(
        group_id=group.id,
        payer_user_id=owner.id,
        title="Aylık market alışverişi",
        note=None,
        expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
        total_amount_in_minor=total_amount_in_minor,
        currency="try",
        split_type=ExpenseSplitType.equal,
        shares=shares
        or [
            (owner.id, 6_250),
            (member.id, 6_250),
        ],
    )


@pytest.mark.asyncio
async def test_repository_persists_expense_and_integer_shares(
    repository_context,
) -> None:
    session, repository, group, owner, member = repository_context

    expense = await _create_expense(
        repository,
        group=group,
        owner=owner,
        member=member,
    )
    await session.commit()

    stored = await repository.get_by_id(expense.id)
    assert stored is not None
    assert stored.group_id == group.id
    assert stored.payer_user_id == owner.id
    assert stored.currency == "TRY"
    assert stored.split_type == ExpenseSplitType.equal
    assert stored.total_amount_in_minor == 12_500
    assert isinstance(stored.total_amount_in_minor, int)
    assert len(stored.shares) == 2
    assert sum(share.amount_in_minor for share in stored.shares) == 12_500
    assert all(isinstance(share.amount_in_minor, int) for share in stored.shares)
    assert all(share.status == ExpenseShareStatus.open for share in stored.shares)
    assert all(share.settled_at is None for share in stored.shares)


@pytest.mark.asyncio
async def test_database_rejects_duplicate_user_share(
    repository_context,
) -> None:
    session, repository, group, owner, member = repository_context

    with pytest.raises(IntegrityError):
        await _create_expense(
            repository,
            group=group,
            owner=owner,
            member=member,
            shares=[
                (member.id, 6_250),
                (member.id, 6_250),
            ],
        )
    await session.rollback()


@pytest.mark.asyncio
async def test_database_rejects_negative_expense_total(
    repository_context,
) -> None:
    session, repository, group, owner, member = repository_context

    with pytest.raises(IntegrityError):
        await _create_expense(
            repository,
            group=group,
            owner=owner,
            member=member,
            total_amount_in_minor=-1,
        )
    await session.rollback()


@pytest.mark.asyncio
async def test_database_rejects_negative_share_amount(
    repository_context,
) -> None:
    session, repository, group, owner, member = repository_context

    with pytest.raises(IntegrityError):
        await _create_expense(
            repository,
            group=group,
            owner=owner,
            member=member,
            total_amount_in_minor=0,
            shares=[
                (owner.id, -1),
                (member.id, 1),
            ],
        )
    await session.rollback()


@pytest.mark.asyncio
async def test_soft_deleted_expense_is_hidden_by_default(
    repository_context,
) -> None:
    session, repository, group, owner, member = repository_context
    expense = await _create_expense(
        repository,
        group=group,
        owner=owner,
        member=member,
    )
    await session.commit()

    deleted_at = datetime(2026, 8, 11, 13, 0, tzinfo=UTC)
    await repository.soft_delete(expense, deleted_at=deleted_at)
    await session.commit()

    assert await repository.get_by_id(expense.id) is None
    assert await repository.list_for_group(group.id) == []

    deleted = await repository.get_by_id(
        expense.id,
        include_deleted=True,
    )
    assert deleted is not None
    assert deleted.deleted_at is not None
