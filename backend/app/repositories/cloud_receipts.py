import uuid
from datetime import datetime

from sqlalchemy import and_, exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cloud_receipt import CloudReceipt, CloudReceiptStatus
from app.models.group_expense import GroupExpense


class CloudReceiptRepository:
    """Personal (non-group) CloudReceipt access for sync/pull.

    Group expense itemization also writes CloudReceipt rows
    (`GroupExpenseService.create_itemized_from_receipt_draft`), but those
    belong to the Gruplarım feature and must stay out of the personal
    sync feed per the app's PRD-driven separation of group and personal
    data (see CLAUDE.md). A receipt referenced by a `GroupExpense.receipt_id`
    is therefore excluded here.
    """

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def add(self, receipt: CloudReceipt) -> CloudReceipt:
        self.session.add(receipt)
        await self.session.flush()
        return receipt

    async def list_changes(
        self,
        *,
        user_id: uuid.UUID,
        limit: int,
        after_updated_at: datetime | None = None,
        after_id: uuid.UUID | None = None,
    ) -> list[CloudReceipt]:
        not_linked_to_group_expense = ~exists(
            select(GroupExpense.id).where(GroupExpense.receipt_id == CloudReceipt.id)
        )
        statement = select(CloudReceipt).where(
            CloudReceipt.user_id == user_id,
            CloudReceipt.status == CloudReceiptStatus.approved,
            not_linked_to_group_expense,
        )
        if after_updated_at is not None and after_id is not None:
            statement = statement.where(
                or_(
                    CloudReceipt.updated_at > after_updated_at,
                    and_(
                        CloudReceipt.updated_at == after_updated_at,
                        CloudReceipt.id > after_id,
                    ),
                )
            )
        statement = statement.order_by(
            CloudReceipt.updated_at,
            CloudReceipt.id,
        ).limit(limit)
        return list((await self.session.scalars(statement)).all())

    async def list_pending(self, *, user_id: uuid.UUID) -> list[CloudReceipt]:
        not_linked_to_group_expense = ~exists(
            select(GroupExpense.id).where(GroupExpense.receipt_id == CloudReceipt.id)
        )
        statement = (
            select(CloudReceipt)
            .where(
                CloudReceipt.user_id == user_id,
                CloudReceipt.status == CloudReceiptStatus.draft,
                CloudReceipt.deleted_at.is_(None),
                not_linked_to_group_expense,
            )
            .order_by(CloudReceipt.created_at)
        )
        return list((await self.session.scalars(statement)).all())

    async def get_draft_by_id(
        self, *, user_id: uuid.UUID, receipt_id: uuid.UUID
    ) -> CloudReceipt | None:
        statement = select(CloudReceipt).where(
            CloudReceipt.id == receipt_id,
            CloudReceipt.user_id == user_id,
            CloudReceipt.status == CloudReceiptStatus.draft,
        )
        return await self.session.scalar(statement)
