import uuid
from collections.abc import Iterable

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_email(self, email: str) -> User | None:
        return await self.session.scalar(select(User).where(User.email == email))

    async def get_by_id(self, user_id: uuid.UUID) -> User | None:
        return await self.session.get(User, user_id)

    async def list_by_ids(self, user_ids: Iterable[uuid.UUID]) -> list[User]:
        ids = list(user_ids)
        if not ids:
            return []
        return list(
            (await self.session.scalars(select(User).where(User.id.in_(ids)))).all()
        )

    async def add(self, user: User) -> User:
        self.session.add(user)
        await self.session.flush()
        return user
