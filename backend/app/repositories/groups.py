import uuid
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.group import Group, GroupMember, GroupRole


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
    ) -> Group:
        group = Group(
            name=name,
            description=description,
            currency=currency.upper(),
            created_by=created_by,
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
    ) -> Group | None:
        statement = select(Group).where(Group.id == group_id)
        if include_members:
            statement = statement.options(selectinload(Group.members))
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
            .order_by(Group.created_at, Group.id)
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
    ) -> GroupMember:
        member = GroupMember(
            group_id=group_id,
            user_id=user_id,
            role=role,
        )
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
    ) -> list[Group]:
        """Resolve owned groups before the user row is hard-deleted.

        The database removes the user's memberships with ON DELETE CASCADE and
        preserves groups by setting groups.created_by to NULL. Before that
        happens, this method promotes the oldest active admin/member. A group
        with no successor is archived.
        """

        statement = (
            select(Group)
            .join(GroupMember)
            .where(
                GroupMember.user_id == user_id,
                GroupMember.role == GroupRole.owner,
                GroupMember.left_at.is_(None),
                Group.archived_at.is_(None),
            )
            .options(selectinload(Group.members))
            .execution_options(populate_existing=True)
        )
        owned_groups = list(
            (await self.session.scalars(statement)).unique().all()
        )

        role_order = {
            GroupRole.admin: 0,
            GroupRole.member: 1,
            GroupRole.owner: 2,
        }
        for group in owned_groups:
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
        return owned_groups

    async def delete(self, group: Group) -> None:
        await self.session.delete(group)
        await self.session.flush()
