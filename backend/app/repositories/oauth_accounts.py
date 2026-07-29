import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.oauth_account import OAuthAccount, OAuthProvider


class OAuthAccountRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_provider_subject(
        self,
        *,
        provider: OAuthProvider,
        subject: str,
    ) -> OAuthAccount | None:
        return await self.session.scalar(
            select(OAuthAccount).where(
                OAuthAccount.provider == provider,
                OAuthAccount.provider_subject == subject,
            )
        )

    async def list_for_user(self, user_id: uuid.UUID) -> list[OAuthAccount]:
        result = await self.session.scalars(
            select(OAuthAccount).where(OAuthAccount.user_id == user_id)
        )
        return list(result)

    async def add(self, account: OAuthAccount) -> OAuthAccount:
        self.session.add(account)
        await self.session.flush()
        return account
