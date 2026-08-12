import uuid
from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime
from decimal import ROUND_FLOOR, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.cloud_receipt import CloudReceipt, CloudReceiptLineItem
from app.models.group import Group, GroupMember
from app.models.group_expense import (
    ExpenseExtraAmountType,
    ExpenseLineItemAssignment,
    ExpenseSplitType,
    GroupExpense,
)
from app.models.user import User
from app.repositories.group_expenses import GroupExpenseRepository


@dataclass(frozen=True, slots=True)
class LineItemAssignmentInput:
    receipt_line_item_id: uuid.UUID
    user_id: uuid.UUID
    amount_in_minor: int
    quantity_share_milli: int | None = None


@dataclass(frozen=True, slots=True)
class ExtraAmountShareInput:
    user_id: uuid.UUID
    amount_in_minor: int


@dataclass(frozen=True, slots=True)
class ExtraAmountInput:
    type: ExpenseExtraAmountType
    label: str | None
    amount_in_minor: int
    shares: Sequence[ExtraAmountShareInput]


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


class FastSplitValidationError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def calculate_equal_shares(
    total_amount_in_minor: int, participant_ids: Sequence[uuid.UUID]
) -> list[tuple[uuid.UUID, int]]:
    if total_amount_in_minor <= 0 or not participant_ids:
        raise FastSplitValidationError("invalid_amount")
    ordered = list(participant_ids)
    quotient, remainder = divmod(total_amount_in_minor, len(ordered))
    return [
        (user_id, quotient + (index < remainder))
        for index, user_id in enumerate(ordered)
    ]


def calculate_percentage_shares(
    total_amount_in_minor: int,
    percentages: Sequence[tuple[uuid.UUID, int]],
) -> list[tuple[uuid.UUID, int]]:
    if total_amount_in_minor <= 0 or not percentages:
        raise FastSplitValidationError("invalid_amount")
    if sum(value for _, value in percentages) != 10_000:
        raise FastSplitValidationError("percentage_total_must_be_100")
    ordered = list(percentages)
    raw = [Decimal(total_amount_in_minor) * value / 10_000 for _, value in ordered]
    amounts = [int(value.to_integral_value(rounding=ROUND_FLOOR)) for value in raw]
    remainder = total_amount_in_minor - sum(amounts)
    # Stable UUID ordering makes the penny rule reproducible on every platform.
    for index in range(remainder):
        amounts[index] += 1
    return [(item[0], amounts[index]) for index, item in enumerate(ordered)]


def validate_exact_shares(
    total_amount_in_minor: int,
    shares: Sequence[tuple[uuid.UUID, int]],
) -> list[tuple[uuid.UUID, int]]:
    if (
        total_amount_in_minor <= 0
        or not shares
        or any(value < 0 for _, value in shares)
    ):
        raise FastSplitValidationError("invalid_amount")
    if sum(value for _, value in shares) != total_amount_in_minor:
        raise FastSplitValidationError("exact_total_must_match_expense")
    return sorted(shares, key=lambda item: str(item[0]))


class GroupExpenseService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = GroupExpenseRepository(session)

    async def create_fast_split(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        payer_user_id: uuid.UUID,
        receipt_id: uuid.UUID | None,
        title: str,
        expense_date: datetime,
        total_amount_in_minor: int,
        currency: str,
        split_type: ExpenseSplitType,
        participants: Sequence[tuple[uuid.UUID, int | None]],
        note: str | None = None,
        idempotency_key: str | None = None,
        idempotency_request_hash: str | None = None,
    ) -> tuple[GroupExpense, bool]:
        if idempotency_key:
            existing = await self.repository.get_by_idempotency_key(
                group_id=group_id, created_by_id=actor_user_id, key=idempotency_key
            )
            if existing is not None:
                if existing.idempotency_request_hash != idempotency_request_hash:
                    raise FastSplitValidationError("idempotency_key_reused")
                return existing, True
        group = await self.session.get(Group, group_id)
        if group is None:
            raise FastSplitValidationError("group_not_found")
        if group.archived_at is not None:
            raise FastSplitValidationError("group_forbidden")
        if currency.upper() != group.currency.upper():
            raise FastSplitValidationError("currency_mismatch")
        if receipt_id is not None:
            receipt = await self.session.scalar(
                select(CloudReceipt).where(
                    CloudReceipt.id == receipt_id,
                    CloudReceipt.user_id == actor_user_id,
                    CloudReceipt.deleted_at.is_(None),
                )
            )
            if receipt is None:
                raise FastSplitValidationError("receipt_not_synced")
        participant_ids = [user_id for user_id, _ in participants]
        required_ids = {actor_user_id, payer_user_id, *participant_ids}
        active = set(
            (
                await self.session.scalars(
                    select(GroupMember.user_id).where(
                        GroupMember.group_id == group_id,
                        GroupMember.user_id.in_(tuple(required_ids)),
                        GroupMember.left_at.is_(None),
                    )
                )
            ).all()
        )
        if required_ids - active:
            raise FastSplitValidationError("member_not_found")
        if split_type is ExpenseSplitType.equal:
            shares = calculate_equal_shares(total_amount_in_minor, participant_ids)
        elif split_type is ExpenseSplitType.percentage:
            shares = calculate_percentage_shares(
                total_amount_in_minor,
                [
                    (user_id, value)
                    for user_id, value in participants
                    if isinstance(value, int)
                ],
            )
        elif split_type is ExpenseSplitType.fixed_amount:
            shares = validate_exact_shares(
                total_amount_in_minor,
                [
                    (user_id, value)
                    for user_id, value in participants
                    if isinstance(value, int)
                ],
            )
        else:
            raise FastSplitValidationError("invalid_split_type")
        expense = await self.repository.create(
            group_id=group_id,
            receipt_id=receipt_id,
            payer_user_id=payer_user_id,
            created_by_id=actor_user_id,
            title=title,
            note=note,
            expense_date=expense_date,
            total_amount_in_minor=total_amount_in_minor,
            currency=currency,
            split_type=split_type,
            shares=shares,
            idempotency_key=idempotency_key,
            idempotency_request_hash=idempotency_request_hash,
        )
        return expense, False

    async def get_expense_share_display_names(
        self,
        expense: GroupExpense,
    ) -> dict[uuid.UUID, str]:
        user_ids = {share.user_id for share in expense.shares}
        if not user_ids:
            return {}

        statement = select(User.id, User.display_name).where(
            User.id.in_(tuple(user_ids))
        )
        rows = (await self.session.execute(statement)).all()
        active_names = {
            user_id: display_name or "Kullanıcı" for user_id, display_name in rows
        }

        return {
            user_id: active_names.get(user_id, "Silinmiş kullanıcı")
            for user_id in user_ids
        }

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
        extra_amounts: Sequence[ExtraAmountInput] = (),
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

            amounts_by_line_item[assignment.receipt_line_item_id] += (
                assignment.amount_in_minor
            )
            amounts_by_user[assignment.user_id] += assignment.amount_in_minor

            if assignment.quantity_share_milli is not None:
                quantities_by_line_item[assignment.receipt_line_item_id] += (
                    assignment.quantity_share_milli
                )

        extra_amount_values: list[
            tuple[
                ExpenseExtraAmountType,
                str | None,
                int,
                tuple[tuple[uuid.UUID, int], ...],
            ]
        ] = []
        extra_participant_user_ids: set[uuid.UUID] = set()

        for extra_amount in extra_amounts:
            if extra_amount.amount_in_minor <= 0:
                raise ItemizedExpenseValidationError("invalid_request")

            normalized_label = (
                extra_amount.label.strip() if extra_amount.label is not None else None
            )
            if normalized_label == "":
                normalized_label = None
            if (
                extra_amount.type is ExpenseExtraAmountType.other
                and normalized_label is None
            ):
                raise ItemizedExpenseValidationError("invalid_request")

            seen_extra_user_ids: set[uuid.UUID] = set()
            extra_share_values: list[tuple[uuid.UUID, int]] = []
            extra_share_total = 0

            for share in extra_amount.shares:
                if share.user_id in seen_extra_user_ids:
                    raise ItemizedExpenseValidationError("invalid_request")
                if share.amount_in_minor < 0:
                    raise ItemizedExpenseValidationError("invalid_request")

                seen_extra_user_ids.add(share.user_id)
                extra_participant_user_ids.add(share.user_id)
                extra_share_total += share.amount_in_minor
                amounts_by_user[share.user_id] += share.amount_in_minor
                extra_share_values.append(
                    (
                        share.user_id,
                        share.amount_in_minor,
                    )
                )

            if extra_share_total != extra_amount.amount_in_minor:
                raise ItemizedExpenseValidationError("invalid_split_total")

            extra_amount_values.append(
                (
                    extra_amount.type,
                    normalized_label,
                    extra_amount.amount_in_minor,
                    tuple(extra_share_values),
                )
            )

        participant_user_ids = {
            payer_user_id,
            *(assignment.user_id for assignment in assignments),
            *extra_participant_user_ids,
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
            created_by_id=actor_user_id,
            title=title,
            note=note,
            expense_date=expense_date,
            total_amount_in_minor=total_amount_in_minor,
            currency=normalized_currency,
            split_type=ExpenseSplitType.itemized,
            shares=share_values,
            line_item_assignments=assignment_values,
            extra_amounts=extra_amount_values,
        )
