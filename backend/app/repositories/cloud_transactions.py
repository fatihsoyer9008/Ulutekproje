import uuid
from datetime import datetime

from sqlalchemy import and_, case, func, or_, select, update
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.assistant_schemas import (
    AssistantCategorySummary,
    AssistantFinancialSummary,
    AssistantLargestExpense,
    AssistantMerchantSummary,
)
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

    async def summarize_for_assistant(
        self,
        *,
        user_id: uuid.UUID,
        period_start_utc: datetime,
        period_end_utc: datetime,
    ) -> AssistantFinancialSummary:
        filters = (
            CloudTransaction.user_id == user_id,
            CloudTransaction.deleted_at.is_(None),
            CloudTransaction.transaction_date >= period_start_utc,
            CloudTransaction.transaction_date < period_end_utc,
        )

        expense_total = func.coalesce(
            func.sum(
                case(
                    (
                        CloudTransaction.transaction_type == "expense",
                        CloudTransaction.amount_in_minor,
                    ),
                    else_=0,
                )
            ),
            0,
        ).label("expense_total_in_minor")
        income_total = func.coalesce(
            func.sum(
                case(
                    (
                        CloudTransaction.transaction_type == "income",
                        CloudTransaction.amount_in_minor,
                    ),
                    else_=0,
                )
            ),
            0,
        ).label("income_total_in_minor")

        totals_row = (
            await self.session.execute(
                select(
                    expense_total,
                    income_total,
                    func.count(CloudTransaction.id).label("transaction_count"),
                    func.max(CloudTransaction.updated_at).label("data_as_of"),
                ).where(*filters)
            )
        ).one()

        category_total = func.sum(CloudTransaction.amount_in_minor).label(
            "total_in_minor"
        )
        category_count = func.count(CloudTransaction.id).label("transaction_count")
        category_rows = (
            await self.session.execute(
                select(
                    CloudTransaction.category,
                    category_total,
                    category_count,
                )
                .where(
                    *filters,
                    CloudTransaction.transaction_type == "expense",
                )
                .group_by(CloudTransaction.category)
                .order_by(category_total.desc(), CloudTransaction.category)
                .limit(20)
            )
        ).all()

        merchant_total = func.sum(CloudTransaction.amount_in_minor).label(
            "total_in_minor"
        )
        merchant_count = func.count(CloudTransaction.id).label("transaction_count")
        merchant_rows = (
            await self.session.execute(
                select(
                    CloudTransaction.merchant_name,
                    merchant_total,
                    merchant_count,
                )
                .where(
                    *filters,
                    CloudTransaction.transaction_type == "expense",
                    CloudTransaction.merchant_name.is_not(None),
                    CloudTransaction.merchant_name != "",
                )
                .group_by(CloudTransaction.merchant_name)
                .order_by(merchant_total.desc(), CloudTransaction.merchant_name)
                .limit(10)
            )
        ).all()

        largest_rows = (
            await self.session.execute(
                select(
                    CloudTransaction.amount_in_minor,
                    CloudTransaction.category,
                    CloudTransaction.merchant_name,
                    CloudTransaction.transaction_date,
                )
                .where(
                    *filters,
                    CloudTransaction.transaction_type == "expense",
                )
                .order_by(
                    CloudTransaction.amount_in_minor.desc(),
                    CloudTransaction.transaction_date.desc(),
                )
                .limit(5)
            )
        ).all()

        return AssistantFinancialSummary(
            period_start_utc=period_start_utc,
            period_end_utc=period_end_utc,
            expense_total_in_minor=int(totals_row.expense_total_in_minor),
            income_total_in_minor=int(totals_row.income_total_in_minor),
            transaction_count=int(totals_row.transaction_count),
            data_as_of=totals_row.data_as_of,
            categories=[
                AssistantCategorySummary(
                    category=row.category,
                    total_in_minor=int(row.total_in_minor),
                    transaction_count=int(row.transaction_count),
                )
                for row in category_rows
            ],
            merchants=[
                AssistantMerchantSummary(
                    merchant_name=row.merchant_name,
                    total_in_minor=int(row.total_in_minor),
                    transaction_count=int(row.transaction_count),
                )
                for row in merchant_rows
            ],
            largest_expenses=[
                AssistantLargestExpense(
                    amount_in_minor=int(row.amount_in_minor),
                    category=row.category,
                    merchant_name=row.merchant_name,
                    transaction_date=row.transaction_date,
                )
                for row in largest_rows
            ],
        )

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
