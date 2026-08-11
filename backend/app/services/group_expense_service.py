import uuid
from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cloud_receipt import CloudReceipt, CloudReceiptLineItem
from app.models.group import Group, GroupMember
from app.models.group_expense import (
    ExpenseLineItemAssignment,
    ExpenseSplitType,
    GroupExpense,
)
from app.repositories.group_expenses import GroupExpenseRepository


@dataclass(frozen=True, slots=True)
class LineItemAssignmentInput:
    receipt_line_item_id: uuid.UUID
    user_id: uuid.UUID
    amount_in_minor: int
    quantity_share_milli: int | None = None


class ItemizedExpenseValidationError(ValueError):
    def __init__(
        self,
        code: str,
        *,
        unassigned_receipt_line_item_ids: Sequence[uuid.UUID] = (),
    ) -> None:
        super().__init__(code)
        self.code = code
        self.unassigned_receipt_line_item_ids = tuple(unassigned_receipt_line_item_ids)


class GroupExpenseService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = GroupExpenseRepository(session)

    async def create_itemized(
        self,
        *,
        group_id: uuid.UUID,
        receipt_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        payer_user_id: uuid.UUID,
        title: str,
        expense_date: datetime,
        total_amount_in_minor: int,
        currency: str,
        assignments: Sequence[LineItemAssignmentInput],
        extra_amount_shares: Sequence[tuple[uuid.UUID, int]] = (),
        note: str | None = None,
    ) -> GroupExpense:
        group = await self.session.get(Group, group_id)
        if group is None:
            raise ItemizedExpenseValidationError("group_not_found")
        if group.archived_at is not None:
            raise ItemizedExpenseValidationError("group_forbidden")
        if total_amount_in_minor <= 0:
            raise ItemizedExpenseValidationError("invalid_request")

        normalized_currency = currency.upper()
        if normalized_currency != group.currency.upper():
            raise ItemizedExpenseValidationError("currency_mismatch")

        actor_membership = await self.session.get(
            GroupMember,
            (group_id, actor_user_id),
        )
        if actor_membership is None or actor_membership.left_at is not None:
            raise ItemizedExpenseValidationError("group_forbidden")

        receipt_statement = select(CloudReceipt).where(
            CloudReceipt.id == receipt_id,
            CloudReceipt.user_id == actor_user_id,
            CloudReceipt.deleted_at.is_(None),
        )
        receipt = await self.session.scalar(receipt_statement)
        if receipt is None:
            raise ItemizedExpenseValidationError("receipt_not_synced")
        if receipt.currency.upper() != group.currency.upper():
            raise ItemizedExpenseValidationError("currency_mismatch")

        line_item_statement = (
            select(CloudReceiptLineItem)
            .where(CloudReceiptLineItem.receipt_id == receipt_id)
            .with_for_update()
        )
        line_items = list((await self.session.scalars(line_item_statement)).all())
        if not line_items:
            raise ItemizedExpenseValidationError("invalid_request")

        line_items_by_id = {line_item.id: line_item for line_item in line_items}
        provided_line_item_ids = {
            assignment.receipt_line_item_id for assignment in assignments
        }
        if not provided_line_item_ids.issubset(line_items_by_id):
            raise ItemizedExpenseValidationError("receipt_not_synced")

        if provided_line_item_ids:
            existing_assignment_statement = (
                select(ExpenseLineItemAssignment.expense_id)
                .where(
                    ExpenseLineItemAssignment.receipt_line_item_id.in_(
                        tuple(provided_line_item_ids)
                    )
                )
                .limit(1)
            )
            existing_expense_id = await self.session.scalar(
                existing_assignment_statement
            )
            if existing_expense_id is not None:
                raise ItemizedExpenseValidationError("invalid_request")

        assignment_keys: set[tuple[uuid.UUID, uuid.UUID]] = set()
        amounts_by_line_item: dict[uuid.UUID, int] = defaultdict(int)
        quantities_by_line_item: dict[uuid.UUID, int] = defaultdict(int)
        amounts_by_user: dict[uuid.UUID, int] = defaultdict(int)

        for assignment in assignments:
            assignment_key = (
                assignment.receipt_line_item_id,
                assignment.user_id,
            )
            if assignment_key in assignment_keys:
                raise ItemizedExpenseValidationError("invalid_request")
            assignment_keys.add(assignment_key)

            if assignment.amount_in_minor < 0:
                raise ItemizedExpenseValidationError("invalid_request")
            if (
                assignment.quantity_share_milli is not None
                and assignment.quantity_share_milli <= 0
            ):
                raise ItemizedExpenseValidationError("invalid_request")

            amounts_by_line_item[
                assignment.receipt_line_item_id
            ] += assignment.amount_in_minor
            amounts_by_user[assignment.user_id] += assignment.amount_in_minor

            if assignment.quantity_share_milli is not None:
                quantities_by_line_item[
                    assignment.receipt_line_item_id
                ] += assignment.quantity_share_milli

        for user_id, amount_in_minor in extra_amount_shares:
            if amount_in_minor < 0:
                raise ItemizedExpenseValidationError("invalid_request")
            amounts_by_user[user_id] += amount_in_minor

        participant_user_ids = {
            payer_user_id,
            *(assignment.user_id for assignment in assignments),
            *(user_id for user_id, _ in extra_amount_shares),
        }
        active_member_statement = select(GroupMember.user_id).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id.in_(tuple(participant_user_ids)),
            GroupMember.left_at.is_(None),
        )
        active_member_ids = set(
            (await self.session.scalars(active_member_statement)).all()
        )
        if participant_user_ids - active_member_ids:
            raise ItemizedExpenseValidationError("member_not_found")

        unassigned_ids = tuple(
            sorted(
                set(line_items_by_id) - provided_line_item_ids,
                key=str,
            )
        )
        if unassigned_ids:
            raise ItemizedExpenseValidationError(
                "unassigned_line_items",
                unassigned_receipt_line_item_ids=unassigned_ids,
            )

        for line_item_id, line_item in line_items_by_id.items():
            assigned_amount = amounts_by_line_item[line_item_id]
            if assigned_amount != line_item.price_in_minor:
                raise ItemizedExpenseValidationError("invalid_split_total")

            assigned_quantity = quantities_by_line_item[line_item_id]
            if (
                assigned_quantity > 0
                and line_item.quantity is not None
                and assigned_quantity > int(line_item.quantity * 1000)
            ):
                raise ItemizedExpenseValidationError("invalid_request")

        calculated_total = sum(amounts_by_user.values())
        if calculated_total != total_amount_in_minor:
            raise ItemizedExpenseValidationError("invalid_split_total")

        share_values = sorted(
            amounts_by_user.items(),
            key=lambda item: str(item[0]),
        )
        assignment_values = [
            (
                assignment.receipt_line_item_id,
                assignment.user_id,
                assignment.amount_in_minor,
                assignment.quantity_share_milli,
            )
            for assignment in assignments
        ]

        return await self.repository.create(
            group_id=group_id,
            receipt_id=receipt_id,
            payer_user_id=payer_user_id,
            title=title,
            note=note,
            expense_date=expense_date,
            total_amount_in_minor=total_amount_in_minor,
            currency=normalized_currency,
            split_type=ExpenseSplitType.itemized,
            shares=share_values,
            line_item_assignments=assignment_values,
        )
