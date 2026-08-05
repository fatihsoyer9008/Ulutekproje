import uuid
from datetime import datetime

from sqlalchemy import and_, or_, select, update
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cloud_transaction import CloudTransaction


class CloudTransactionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_for_user(
        self,
        *,
        user_id: uuid.UUID,
        client_record_id: uuid.UUID,
    ) -> CloudTransaction | None:
        return await self.session.scalar(
            select(CloudTransaction).where(
                CloudTransaction.user_id == user_id,
                CloudTransaction.client_record_id == client_record_id,
            )
        )

    async def try_insert(
        self,
        *,
        values: dict[str, object],
    ) -> CloudTransaction | None:
        dialect_name = self.session.get_bind().dialect.name
        if dialect_name == "postgresql":
            statement = postgresql_insert(CloudTransaction).values(**values)
        elif dialect_name == "sqlite":
            statement = sqlite_insert(CloudTransaction).values(**values)
        else:
            raise RuntimeError(f"Unsupported database dialect: {dialect_name}")

        statement = statement.on_conflict_do_nothing(
            index_elements=["user_id", "client_record_id"]
        ).returning(CloudTransaction)
        return await self.session.scalar(statement)

    async def update_if_newer(
        self,
        *,
        user_id: uuid.UUID,
        client_record_id: uuid.UUID,
        client_updated_at: datetime,
        values: dict[str, object],
    ) -> CloudTransaction | None:
        statement = (
            update(CloudTransaction)
            .where(
                CloudTransaction.user_id == user_id,
                CloudTransaction.client_record_id == client_record_id,
                CloudTransaction.client_updated_at < client_updated_at,
            )
            .values(**values)
            .returning(CloudTransaction)
            .execution_options(
                synchronize_session=False,
                populate_existing=True,
            )
        )
        return await self.session.scalar(statement)

    async def delete_if_newer(
        self,
        *,
        user_id: uuid.UUID,
        client_record_id: uuid.UUID,
        client_updated_at: datetime,
        deleted_at: datetime,
    ) -> CloudTransaction | None:
        statement = (
            update(CloudTransaction)
            .where(
                CloudTransaction.user_id == user_id,
                CloudTransaction.client_record_id == client_record_id,
                CloudTransaction.client_updated_at < client_updated_at,
            )
            .values(
                client_updated_at=client_updated_at,
                deleted_at=deleted_at,
                updated_at=deleted_at,
            )
            .returning(CloudTransaction)
            .execution_options(
                synchronize_session=False,
                populate_existing=True,
            )
        )
        return await self.session.scalar(statement)

    async def list_changes(
        self,
        *,
        user_id: uuid.UUID,
        limit: int,
        after_updated_at: datetime | None = None,
        after_id: uuid.UUID | None = None,
    ) -> list[CloudTransaction]:
        statement = select(CloudTransaction).where(CloudTransaction.user_id == user_id)
        if after_updated_at is not None and after_id is not None:
            statement = statement.where(
                or_(
                    CloudTransaction.updated_at > after_updated_at,
                    and_(
                        CloudTransaction.updated_at == after_updated_at,
                        CloudTransaction.id > after_id,
                    ),
                )
            )
        statement = statement.order_by(
            CloudTransaction.updated_at,
            CloudTransaction.id,
        ).limit(limit)
        return list((await self.session.scalars(statement)).all())
