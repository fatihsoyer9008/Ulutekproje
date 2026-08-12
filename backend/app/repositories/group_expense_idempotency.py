import uuid

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.expense_idempotency import GroupExpenseIdempotencyRecord


class GroupExpenseIdempotencyRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def try_create(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        idempotency_key_hash: str,
        request_hash: str,
    ) -> GroupExpenseIdempotencyRecord | None:
        values = {
            "id": uuid.uuid4(),
            "group_id": group_id,
            "actor_user_id": actor_user_id,
            "expense_id": None,
            "idempotency_key_hash": idempotency_key_hash,
            "request_hash": request_hash,
        }
        dialect_name = self.session.get_bind().dialect.name
        if dialect_name == "postgresql":
            statement = postgresql_insert(GroupExpenseIdempotencyRecord).values(
                **values
            )
        elif dialect_name == "sqlite":
            statement = sqlite_insert(GroupExpenseIdempotencyRecord).values(**values)
        else:
            raise RuntimeError(f"Unsupported database dialect: {dialect_name}")

        statement = statement.on_conflict_do_nothing(
            index_elements=[
                "group_id",
                "actor_user_id",
                "idempotency_key_hash",
            ]
        ).returning(GroupExpenseIdempotencyRecord)

        return await self.session.scalar(statement)

    async def get(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        idempotency_key_hash: str,
    ) -> GroupExpenseIdempotencyRecord | None:
        return await self.session.scalar(
            select(GroupExpenseIdempotencyRecord).where(
                GroupExpenseIdempotencyRecord.group_id == group_id,
                GroupExpenseIdempotencyRecord.actor_user_id == actor_user_id,
                GroupExpenseIdempotencyRecord.idempotency_key_hash
                == idempotency_key_hash,
            )
        )
