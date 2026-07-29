import uuid
from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.one_time_token import OneTimeToken, OneTimeTokenPurpose


class OneTimeTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def consume_active_for_update(
        self,
        *,
        token_hash: str,
        purpose: OneTimeTokenPurpose,
        now: datetime,
    ) -> OneTimeToken | None:
        return await self.session.scalar(
            select(OneTimeToken)
            .where(
                OneTimeToken.token_hash == token_hash,
                OneTimeToken.purpose == purpose,
                OneTimeToken.consumed_at.is_(None),
                OneTimeToken.expires_at > now,
            )
            .with_for_update()
        )

    async def invalidate_active(
        self,
        *,
        user_id: uuid.UUID,
        purpose: OneTimeTokenPurpose,
        now: datetime,
    ) -> None:
        await self.session.execute(
            update(OneTimeToken)
            .where(
                OneTimeToken.user_id == user_id,
                OneTimeToken.purpose == purpose,
                OneTimeToken.consumed_at.is_(None),
            )
            .values(consumed_at=now)
        )
