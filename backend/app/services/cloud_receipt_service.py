import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.cloud_receipt_schemas import ApproveReceiptRequest
from app.models.cloud_receipt import CloudReceipt, CloudReceiptStatus
from app.repositories.cloud_receipts import CloudReceiptRepository


class CloudReceiptService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.receipts = CloudReceiptRepository(db)

    async def list_pending(self, *, user_id: uuid.UUID) -> list[CloudReceipt]:
        return await self.receipts.list_pending(user_id=user_id)

    async def approve(
        self,
        *,
        user_id: uuid.UUID,
        receipt_id: uuid.UUID,
        overrides: ApproveReceiptRequest,
    ) -> CloudReceipt | None:
        receipt = await self.receipts.get_draft_by_id(
            user_id=user_id, receipt_id=receipt_id
        )
        if receipt is None:
            return None

        if overrides.merchant_name is not None:
            receipt.merchant_name = overrides.merchant_name
        if overrides.total_amount_in_minor is not None:
            receipt.total_amount_in_minor = overrides.total_amount_in_minor
        if overrides.currency is not None:
            receipt.currency = overrides.currency
        if overrides.receipt_date is not None:
            receipt.receipt_date = overrides.receipt_date
        if overrides.category is not None:
            receipt.category = overrides.category

        receipt.status = CloudReceiptStatus.approved
        await self.db.commit()
        return receipt

    async def reject(
        self, *, user_id: uuid.UUID, receipt_id: uuid.UUID
    ) -> CloudReceipt | None:
        receipt = await self.receipts.get_draft_by_id(
            user_id=user_id, receipt_id=receipt_id
        )
        if receipt is None:
            return None

        receipt.status = CloudReceiptStatus.rejected
        await self.db.commit()
        return receipt
