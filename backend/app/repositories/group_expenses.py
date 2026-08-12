import uuid
from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.group_expense import (
    ExpenseExtraAmount,
    ExpenseExtraAmountShare,
    ExpenseExtraAmountType,
    ExpenseLineItemAssignment,
    ExpenseShare,
    ExpenseSplitType,
    GroupExpense,
)


class GroupExpenseRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        group_id: uuid.UUID,
        payer_user_id: uuid.UUID,
        title: str,
        expense_date: datetime,
        total_amount_in_minor: int,
        currency: str,
        split_type: ExpenseSplitType,
        shares: Sequence[tuple[uuid.UUID, int]],
        line_item_assignments: Sequence[
            tuple[uuid.UUID, uuid.UUID, int, int | None]
        ] = (),
        extra_amounts: Sequence[
            tuple[
                ExpenseExtraAmountType,
                str | None,
                int,
                Sequence[tuple[uuid.UUID, int]],
            ]
        ] = (),
        created_by: uuid.UUID | None = None,
        receipt_id: uuid.UUID | None = None,
        note: str | None = None,
    ) -> GroupExpense:
        expense = GroupExpense(
            group_id=group_id,
            receipt_id=receipt_id,
            payer_user_id=payer_user_id,
            created_by=created_by,
            title=title,
            note=note,
            expense_date=expense_date,
            total_amount_in_minor=total_amount_in_minor,
            currency=currency.upper(),
            split_type=split_type,
        )
        expense.shares.extend(
            ExpenseShare(
                user_id=user_id,
                amount_in_minor=amount_in_minor,
            )
            for user_id, amount_in_minor in shares
        )
        expense.line_item_assignments.extend(
            ExpenseLineItemAssignment(
                receipt_line_item_id=receipt_line_item_id,
                user_id=user_id,
                amount_in_minor=amount_in_minor,
                quantity_share_milli=quantity_share_milli,
            )
            for (
                receipt_line_item_id,
                user_id,
                amount_in_minor,
                quantity_share_milli,
            ) in line_item_assignments
        )

        for (
            extra_type,
            label,
            amount_in_minor,
            extra_shares,
        ) in extra_amounts:
            extra_amount = ExpenseExtraAmount(
                type=extra_type,
                label=label,
                amount_in_minor=amount_in_minor,
            )
            extra_amount.shares.extend(
                ExpenseExtraAmountShare(
                    user_id=user_id,
                    amount_in_minor=share_amount_in_minor,
                )
                for user_id, share_amount_in_minor in extra_shares
            )
            expense.extra_amounts.append(extra_amount)

        self.session.add(expense)
        await self.session.flush()
        return expense

    async def get_by_id(
        self,
        expense_id: uuid.UUID,
        *,
        include_deleted: bool = False,
    ) -> GroupExpense | None:
        statement = (
            select(GroupExpense)
            .where(GroupExpense.id == expense_id)
            .options(
                selectinload(GroupExpense.shares),
                selectinload(GroupExpense.line_item_assignments),
                selectinload(GroupExpense.extra_amounts).selectinload(
                    ExpenseExtraAmount.shares
                ),
            )
        )
        if not include_deleted:
            statement = statement.where(GroupExpense.deleted_at.is_(None))
        return await self.session.scalar(statement)

    async def list_for_group(
        self,
        group_id: uuid.UUID,
        *,
        include_deleted: bool = False,
    ) -> list[GroupExpense]:
        statement = (
            select(GroupExpense)
            .where(GroupExpense.group_id == group_id)
            .options(
                selectinload(GroupExpense.shares),
                selectinload(GroupExpense.line_item_assignments),
                selectinload(GroupExpense.extra_amounts).selectinload(
                    ExpenseExtraAmount.shares
                ),
            )
            .order_by(
                GroupExpense.expense_date.desc(),
                GroupExpense.id.desc(),
            )
        )
        if not include_deleted:
            statement = statement.where(GroupExpense.deleted_at.is_(None))
        return list((await self.session.scalars(statement)).all())

    async def soft_delete(
        self,
        expense: GroupExpense,
        *,
        deleted_at: datetime,
    ) -> GroupExpense:
        expense.deleted_at = deleted_at
        expense.updated_at = deleted_at
        await self.session.flush()
        return expense
