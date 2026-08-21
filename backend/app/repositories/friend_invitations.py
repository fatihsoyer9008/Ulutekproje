import uuid
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.friend_invitation import FriendInvitation


class FriendInvitationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        invited_email: str,
        invited_by_user_id: uuid.UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> FriendInvitation:
        invitation = FriendInvitation(
            invited_email=invited_email,
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
    ) -> FriendInvitation | None:
        statement = select(FriendInvitation).where(
            FriendInvitation.token_hash == token_hash
        )
        if for_update:
            statement = statement.with_for_update()
        return await self.session.scalar(statement)
