import uuid
from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.settlement import Settlement, SettlementIdempotencyRecord


class SettlementRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        group_id: uuid.UUID,
        from_user_id: uuid.UUID,
        to_user_id: uuid.UUID,
        amount_in_minor: int,
        currency: str,
        settled_at: datetime,
        note: str | None,
    ) -> Settlement:
        settlement = Settlement(
            group_id=group_id,
            from_user_id=from_user_id,
            to_user_id=to_user_id,
            amount_in_minor=amount_in_minor,
            currency=currency.upper(),
            settled_at=settled_at,
            note=note,
        )
        self.session.add(settlement)
        await self.session.flush()
        return settlement

    async def get_by_id(
        self,
        settlement_id: uuid.UUID,
    ) -> Settlement | None:
        return await self.session.get(Settlement, settlement_id)

    async def list_for_group(
        self,
        group_id: uuid.UUID,
    ) -> list[Settlement]:
        statement = (
            select(Settlement)
            .where(Settlement.group_id == group_id)
            .order_by(
                Settlement.settled_at.desc(),
                Settlement.id.desc(),
            )
        )
        return list((await self.session.scalars(statement)).all())

    async def list_for_groups(
        self,
        group_ids: Sequence[uuid.UUID],
    ) -> list[Settlement]:
        if not group_ids:
            return []
        statement = select(Settlement).where(Settlement.group_id.in_(group_ids))
        return list((await self.session.scalars(statement)).all())

    async def try_reserve_idempotency(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        idempotency_key_hash: str,
        request_hash: str,
    ) -> SettlementIdempotencyRecord | None:
        values = {
            "id": uuid.uuid4(),
            "group_id": group_id,
            "actor_user_id": actor_user_id,
            "settlement_id": None,
            "idempotency_key_hash": idempotency_key_hash,
            "request_hash": request_hash,
        }

        dialect_name = self.session.get_bind().dialect.name
        if dialect_name == "postgresql":
            statement = postgresql_insert(SettlementIdempotencyRecord).values(**values)
        elif dialect_name == "sqlite":
            statement = sqlite_insert(SettlementIdempotencyRecord).values(**values)
        else:
            raise RuntimeError(f"Unsupported database dialect: {dialect_name}")

        statement = statement.on_conflict_do_nothing(
            index_elements=[
                "group_id",
                "actor_user_id",
                "idempotency_key_hash",
            ]
        ).returning(SettlementIdempotencyRecord)

        return await self.session.scalar(statement)

    async def get_idempotency(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        idempotency_key_hash: str,
    ) -> SettlementIdempotencyRecord | None:
        return await self.session.scalar(
            select(SettlementIdempotencyRecord).where(
                SettlementIdempotencyRecord.group_id == group_id,
                SettlementIdempotencyRecord.actor_user_id == actor_user_id,
                SettlementIdempotencyRecord.idempotency_key_hash
                == idempotency_key_hash,
            )
        )
