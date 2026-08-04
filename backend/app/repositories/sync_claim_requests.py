import uuid

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sync_claim_request import SyncClaimRequest


class SyncClaimRequestRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def try_create(
        self,
        *,
        user_id: uuid.UUID,
        idempotency_key_hash: str,
        request_hash: str,
    ) -> SyncClaimRequest | None:
        values = {
            "id": uuid.uuid4(),
            "user_id": user_id,
            "idempotency_key_hash": idempotency_key_hash,
            "request_hash": request_hash,
            "response_json": None,
        }
        dialect_name = self.session.get_bind().dialect.name
        if dialect_name == "postgresql":
            statement = postgresql_insert(SyncClaimRequest).values(**values)
        elif dialect_name == "sqlite":
            statement = sqlite_insert(SyncClaimRequest).values(**values)
        else:
            raise RuntimeError(f"Unsupported database dialect: {dialect_name}")

        statement = statement.on_conflict_do_nothing(
            index_elements=["user_id", "idempotency_key_hash"]
        ).returning(SyncClaimRequest)
        return await self.session.scalar(statement)

    async def get(
        self,
        *,
        user_id: uuid.UUID,
        idempotency_key_hash: str,
    ) -> SyncClaimRequest | None:
        return await self.session.scalar(
            select(SyncClaimRequest).where(
                SyncClaimRequest.user_id == user_id,
                SyncClaimRequest.idempotency_key_hash == idempotency_key_hash,
            )
        )
