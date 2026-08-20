import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.group import Group, GroupMember, GroupRole


class GroupMemberAlreadyExists(ValueError):
    """Raised when an active membership already exists for the user."""


class GroupRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        name: str,
        created_by: uuid.UUID,
        description: str | None = None,
        currency: str = "TRY",
        is_direct: bool = False,
    ) -> Group:
        group = Group(
            name=name,
            description=description,
            currency=currency.upper(),
            created_by=created_by,
            is_direct=is_direct,
        )
        group.members.append(
            GroupMember(
                user_id=created_by,
                role=GroupRole.owner,
            )
        )
        self.session.add(group)
        await self.session.flush()
        return group

    async def get_by_id(
        self,
        group_id: uuid.UUID,
        *,
        include_members: bool = False,
        for_update: bool = False,
    ) -> Group | None:
        statement = select(Group).where(Group.id == group_id)
        if include_members:
            statement = statement.options(
                selectinload(Group.members).selectinload(GroupMember.user)
            )
        if for_update:
            statement = statement.with_for_update()
        statement = statement.execution_options(populate_existing=True)
        return await self.session.scalar(statement)

    async def list_for_user(
        self,
        user_id: uuid.UUID,
        *,
        include_archived: bool = False,
    ) -> list[Group]:
        statement = (
            select(Group)
            .join(GroupMember)
            .where(
                GroupMember.user_id == user_id,
                GroupMember.left_at.is_(None),
            )
            .options(
                selectinload(Group.members).selectinload(GroupMember.user)
            )
            .order_by(Group.created_at, Group.id)
            .execution_options(populate_existing=True)
        )
        if not include_archived:
            statement = statement.where(Group.archived_at.is_(None))
        return list((await self.session.scalars(statement)).all())

    async def add_member(
        self,
        *,
        group_id: uuid.UUID,
        user_id: uuid.UUID,
        role: GroupRole = GroupRole.member,
        joined_at: datetime | None = None,
    ) -> GroupMember:
        existing = await self.get_member(group_id=group_id, user_id=user_id)
        if existing is not None:
            if existing.left_at is None:
                raise GroupMemberAlreadyExists("member_already_exists")
            existing.left_at = None
            existing.joined_at = joined_at or datetime.now(UTC)
            existing.role = role
            await self.session.flush()
            return existing

        member = GroupMember(
            group_id=group_id,
            user_id=user_id,
            role=role,
        )
        if joined_at is not None:
            member.joined_at = joined_at
        self.session.add(member)
        await self.session.flush()
        return member

    async def get_member(
        self,
        *,
        group_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> GroupMember | None:
        return await self.session.get(GroupMember, (group_id, user_id))

    async def mark_member_left(
        self,
        *,
        group_id: uuid.UUID,
        user_id: uuid.UUID,
        left_at: datetime,
    ) -> GroupMember | None:
        member = await self.get_member(group_id=group_id, user_id=user_id)
        if member is None:
            return None
        member.left_at = left_at
        await self.session.flush()
        return member

    async def prepare_for_user_deletion(
        self,
        *,
        user_id: uuid.UUID,
        archived_at: datetime,
    ) -> list[uuid.UUID]:
        """Resolve and return affected groups before the user is deleted.

        The database removes the user's memberships with ON DELETE CASCADE and
        preserves groups by setting groups.created_by to NULL. Before that
        happens, this method promotes the oldest active admin/member. A group
        with no successor is archived. All active groups containing the user
        are returned so their derived debt summaries can be invalidated after
        the deletion transaction commits.
        """

        statement = (
            select(Group)
            .join(GroupMember)
            .where(
                GroupMember.user_id == user_id,
                GroupMember.left_at.is_(None),
                Group.archived_at.is_(None),
            )
            .options(selectinload(Group.members))
            .execution_options(populate_existing=True)
        )
        affected_groups = list(
            (await self.session.scalars(statement)).unique().all()
        )

        role_order = {
            GroupRole.admin: 0,
            GroupRole.member: 1,
            GroupRole.owner: 2,
        }
        for group in affected_groups:
            deleting_membership = next(
                member
                for member in group.members
                if member.user_id == user_id and member.left_at is None
            )
            if deleting_membership.role is not GroupRole.owner:
                continue

            candidates = [
                member
                for member in group.members
                if member.user_id != user_id and member.left_at is None
            ]
            if not candidates:
                group.archived_at = archived_at
                continue

            successor = min(
                candidates,
                key=lambda member: (
                    role_order[member.role],
                    member.joined_at,
                    str(member.user_id),
                ),
            )
            successor.role = GroupRole.owner

        await self.session.flush()
        return [group.id for group in affected_groups]

    async def delete(self, group: Group) -> None:
        await self.session.delete(group)
        await self.session.flush()
