from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import GroupMember, GroupRole, User
from app.repositories.groups import GroupMemberAlreadyExists, GroupRepository


@pytest_asyncio.fixture
async def repository_context() -> AsyncIterator[
    tuple[AsyncSession, GroupRepository, User, User, User]
]:
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
        owner = User(email="group-owner@example.com")
        admin = User(email="group-admin@example.com")
        member = User(email="group-member@example.com")
        session.add_all([owner, admin, member])
        await session.commit()

        yield session, GroupRepository(session), owner, admin, member

    await engine.dispose()


@pytest.mark.asyncio
async def test_create_group_adds_creator_as_owner(
    repository_context,
) -> None:
    session, repository, owner, _, _ = repository_context

    group = await repository.create(
        name="Ev Arkadaşları",
        description="Ortak ev masrafları",
        currency="try",
        created_by=owner.id,
    )
    await session.commit()

    stored = await repository.get_by_id(group.id, include_members=True)
    assert stored is not None
    assert stored.name == "Ev Arkadaşları"
    assert stored.description == "Ortak ev masrafları"
    assert stored.currency == "TRY"
    assert stored.created_by == owner.id
    assert len(stored.members) == 1
    assert stored.members[0].user_id == owner.id
    assert stored.members[0].role == GroupRole.owner


@pytest.mark.asyncio
async def test_active_group_member_cannot_be_added_twice(repository_context) -> None:
    session, repository, owner, _, member = repository_context
    group = await repository.create(name="Test Grubu", created_by=owner.id)
    await repository.add_member(group_id=group.id, user_id=member.id)
    await session.commit()

    with pytest.raises(
        GroupMemberAlreadyExists,
        match="member_already_exists",
    ):
        await repository.add_member(group_id=group.id, user_id=member.id)


@pytest.mark.asyncio
async def test_former_group_member_is_reactivated_in_place(
    repository_context,
) -> None:
    session, repository, owner, _, member = repository_context
    group = await repository.create(name="Yeniden Katilma", created_by=owner.id)
    membership = await repository.add_member(
        group_id=group.id,
        user_id=member.id,
    )
    await session.commit()

    left_at = datetime(2026, 8, 10, 10, 0, tzinfo=UTC)
    await repository.mark_member_left(
        group_id=group.id,
        user_id=member.id,
        left_at=left_at,
    )
    await session.commit()

    rejoined_at = datetime(2026, 8, 11, 9, 30, tzinfo=UTC)
    reactivated = await repository.add_member(
        group_id=group.id,
        user_id=member.id,
        role=GroupRole.admin,
        joined_at=rejoined_at,
    )
    await session.commit()

    assert reactivated is membership
    assert reactivated.left_at is None
    assert reactivated.joined_at == rejoined_at
    assert reactivated.role == GroupRole.admin
    membership_count = await session.scalar(
        select(func.count())
        .select_from(GroupMember)
        .where(
            GroupMember.group_id == group.id,
            GroupMember.user_id == member.id,
        )
    )
    assert membership_count == 1


@pytest.mark.asyncio
async def test_deleting_group_cascades_memberships(repository_context) -> None:
    session, repository, owner, _, member = repository_context
    group = await repository.create(name="Silinecek Grup", created_by=owner.id)
    await repository.add_member(group_id=group.id, user_id=member.id)
    await session.commit()
    group_id = group.id

    await repository.delete(group)
    await session.commit()

    membership_count = await session.scalar(
        select(func.count())
        .select_from(GroupMember)
        .where(GroupMember.group_id == group_id)
    )
    assert membership_count == 0
    assert await repository.get_by_id(group_id) is None


@pytest.mark.asyncio
async def test_user_deletion_promotes_admin_and_archives_group_without_successor(
    repository_context,
) -> None:
    session, repository, owner, admin, member = repository_context
    promotable_group = await repository.create(
        name="Devredilecek Grup",
        created_by=owner.id,
    )
    admin_membership = await repository.add_member(
        group_id=promotable_group.id,
        user_id=admin.id,
        role=GroupRole.admin,
    )
    member_membership = await repository.add_member(
        group_id=promotable_group.id,
        user_id=member.id,
        role=GroupRole.member,
    )
    now = datetime(2026, 8, 10, 12, 0, tzinfo=UTC)
    admin_membership.joined_at = now
    member_membership.joined_at = now - timedelta(days=1)

    lone_group = await repository.create(
        name="Arşivlenecek Grup",
        created_by=owner.id,
    )
    await session.commit()
    promotable_group_id = promotable_group.id
    lone_group_id = lone_group.id
    admin_id = admin.id
    member_id = member.id

    resolved_group_ids = await repository.prepare_for_user_deletion(
        user_id=owner.id,
        archived_at=now,
    )
    assert set(resolved_group_ids) == {
        promotable_group.id,
        lone_group.id,
    }
    assert admin_membership.role == GroupRole.owner
    assert member_membership.role == GroupRole.member
    assert lone_group.archived_at == now

    await session.delete(owner)
    await session.commit()
    session.expire_all()

    stored_promotable = await repository.get_by_id(
        promotable_group_id,
        include_members=True,
    )
    stored_lone = await repository.get_by_id(lone_group_id, include_members=True)

    assert stored_promotable is not None
    assert stored_promotable.created_by is None
    assert {membership.user_id for membership in stored_promotable.members} == {
        admin_id,
        member_id,
    }
    assert next(
        membership
        for membership in stored_promotable.members
        if membership.user_id == admin_id
    ).role == GroupRole.owner

    assert stored_lone is not None
    assert stored_lone.created_by is None
    assert stored_lone.archived_at is not None
    assert stored_lone.members == []
