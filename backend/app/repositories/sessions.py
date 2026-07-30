import uuid
from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.refresh_session import RefreshSession


class SessionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_hash_for_update(
        self,
        token_hash: str,
    ) -> RefreshSession | None:
        return await self.session.scalar(
            select(RefreshSession)
            .where(RefreshSession.token_hash == token_hash)
            .with_for_update()
        )

    async def add(self, refresh_session: RefreshSession) -> RefreshSession:
        self.session.add(refresh_session)
        await self.session.flush()
        return refresh_session

    async def revoke_family(
        self,
        family_id: uuid.UUID,
        *,
        revoked_at: datetime,
        reuse_detected_at: datetime | None = None,
    ) -> None:
        values: dict[str, datetime] = {"revoked_at": revoked_at}
        if reuse_detected_at is not None:
            values["reuse_detected_at"] = reuse_detected_at
        await self.session.execute(
            update(RefreshSession)
            .where(
                RefreshSession.family_id == family_id,
                RefreshSession.revoked_at.is_(None),
            )
            .values(**values)
        )

    async def revoke_user_sessions(
        self,
        user_id: uuid.UUID,
        *,
        revoked_at: datetime,
    ) -> None:
        await self.session.execute(
            update(RefreshSession)
            .where(
                RefreshSession.user_id == user_id,
                RefreshSession.revoked_at.is_(None),
            )
            .values(revoked_at=revoked_at)
        )
