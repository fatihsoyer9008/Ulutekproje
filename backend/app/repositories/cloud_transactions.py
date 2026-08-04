import uuid
from datetime import datetime

from sqlalchemy import and_, or_, select
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

    async def add(self, transaction: CloudTransaction) -> CloudTransaction:
        self.session.add(transaction)
        await self.session.flush()
        return transaction

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
