import uuid
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.group import GroupRole
from app.models.group_invitation import GroupInvitation


class GroupInvitationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        group_id: uuid.UUID,
        invited_email: str,
        role: GroupRole,
        invited_by_user_id: uuid.UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> GroupInvitation:
        invitation = GroupInvitation(
            group_id=group_id,
            invited_email=invited_email,
            role=role,
            invited_by_user_id=invited_by_user_id,
            token_hash=token_hash,
            expires_at=expires_at,
        )
        self.session.add(invitation)
        await self.session.flush()
        return invitation

    async def get_by_token_hash(
        self,
        token_hash: str,
        *,
        for_update: bool = False,
    ) -> GroupInvitation | None:
        statement = select(GroupInvitation).where(
            GroupInvitation.token_hash == token_hash
        )
        if for_update:
            statement = statement.with_for_update()
        return await self.session.scalar(statement)
