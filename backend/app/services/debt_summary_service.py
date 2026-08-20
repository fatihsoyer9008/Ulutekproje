import uuid
from collections import defaultdict
from collections.abc import Sequence
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.debts import (
    DebtBalance,
    DebtSimplificationService,
    DebtSummary,
    DebtTransfer,
    OverallBalance,
)
from app.models.group import Group
from app.models.group_expense import ExpenseShare, GroupExpense
from app.models.settlement import Settlement
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository
from app.repositories.settlements import SettlementRepository


class DebtSummaryNotFoundError(ValueError):
    pass


class DebtSummaryService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.group_repository = GroupRepository(session)
        self.expense_repository = GroupExpenseRepository(session)
        self.settlement_repository = SettlementRepository(session)

    async def get_for_group(
        self,
        group_id: uuid.UUID,
    ) -> DebtSummary:
        group = await self.group_repository.get_by_id(
            group_id,
            include_members=True,
        )
        if group is None:
            raise DebtSummaryNotFoundError("group_not_found")

        expenses = await self.expense_repository.list_for_group(group_id)
        settlements = await self.settlement_repository.list_for_group(group_id)

        display_names = {
            member.user_id: (
                member.user.display_name or "Kullanıcı"
                if member.user is not None
                else "Silinmiş kullanıcı"
            )
            for member in group.members
        }

        expense_amounts: defaultdict[uuid.UUID, int] = defaultdict(int)
        # Active members belong in the API snapshot even when the group has no
        # financial activity yet. Historical users are added below from the
        # immutable expense/settlement records so old balances are not lost.
        financial_user_ids: set[uuid.UUID] = {
            member.user_id for member in group.members if member.left_at is None
        }

        for expense in expenses:
            financial_user_ids.add(expense.payer_user_id)
            expense_amounts[expense.payer_user_id] += expense.total_amount_in_minor

            for share in expense.shares:
                financial_user_ids.add(share.user_id)
                expense_amounts[share.user_id] -= share.amount_in_minor

        for settlement in settlements:
            financial_user_ids.add(settlement.from_user_id)
            financial_user_ids.add(settlement.to_user_id)

        expense_balances = tuple(
            DebtBalance(
                user_id=str(user_id),
                display_name=display_names.get(
                    user_id,
                    "Silinmiş kullanıcı",
                ),
                net_amount_in_minor=expense_amounts[user_id],
            )
            for user_id in sorted(financial_user_ids, key=str)
        )

        settlement_transfers = tuple(
            DebtTransfer(
                from_user_id=str(settlement.from_user_id),
                to_user_id=str(settlement.to_user_id),
                amount_in_minor=settlement.amount_in_minor,
            )
            for settlement in reversed(settlements)
        )

        settled_balances = DebtSimplificationService.apply_settlements(
            expense_balances,
            settlement_transfers,
        )
        suggested_transfers = DebtSimplificationService.simplify(settled_balances)

        return DebtSummary(
            group_id=str(group.id),
            currency=group.currency,
            balances=settled_balances,
            suggested_transfers=suggested_transfers,
            generated_at=datetime.now(UTC),
        )

    async def get_overall_balance(
        self,
        user_id: uuid.UUID,
    ) -> tuple[OverallBalance, ...]:
        """Net balance for one user across every non-direct, non-archived
        group they have ever taken part in, grouped by currency.

        Mirrors ``get_for_group``'s sign convention (paid - share, then
        settlements applied) but is computed with aggregate queries instead
        of loading every expense/settlement row, since a user may belong to
        many groups.
        """
        totals: defaultdict[str, int] = defaultdict(int)

        paid_rows = await self.session.execute(
            select(
                Group.currency,
                func.coalesce(func.sum(GroupExpense.total_amount_in_minor), 0),
            )
            .select_from(GroupExpense)
            .join(Group, Group.id == GroupExpense.group_id)
            .where(
                GroupExpense.payer_user_id == user_id,
                GroupExpense.deleted_at.is_(None),
                Group.is_direct.is_(False),
                Group.archived_at.is_(None),
            )
            .group_by(Group.currency)
        )
        for currency, amount in paid_rows:
            totals[currency] += amount

        share_rows = await self.session.execute(
            select(
                Group.currency,
                func.coalesce(func.sum(ExpenseShare.amount_in_minor), 0),
            )
            .select_from(ExpenseShare)
            .join(GroupExpense, GroupExpense.id == ExpenseShare.expense_id)
            .join(Group, Group.id == GroupExpense.group_id)
            .where(
                ExpenseShare.user_id == user_id,
                GroupExpense.deleted_at.is_(None),
                Group.is_direct.is_(False),
                Group.archived_at.is_(None),
            )
            .group_by(Group.currency)
        )
        for currency, amount in share_rows:
            totals[currency] -= amount

        settlements_paid_rows = await self.session.execute(
            select(
                Group.currency,
                func.coalesce(func.sum(Settlement.amount_in_minor), 0),
            )
            .select_from(Settlement)
            .join(Group, Group.id == Settlement.group_id)
            .where(
                Settlement.from_user_id == user_id,
                Group.is_direct.is_(False),
                Group.archived_at.is_(None),
            )
            .group_by(Group.currency)
        )
        for currency, amount in settlements_paid_rows:
            totals[currency] += amount

        settlements_received_rows = await self.session.execute(
            select(
                Group.currency,
                func.coalesce(func.sum(Settlement.amount_in_minor), 0),
            )
            .select_from(Settlement)
            .join(Group, Group.id == Settlement.group_id)
            .where(
                Settlement.to_user_id == user_id,
                Group.is_direct.is_(False),
                Group.archived_at.is_(None),
            )
            .group_by(Group.currency)
        )
        for currency, amount in settlements_received_rows:
            totals[currency] -= amount

        # A currency only appears here if the user has at least one expense,
        # share, or settlement row in it — a currency the user is exactly
        # settled up in still reports (net 0, status "settled_up"); a
        # currency the user has never touched is omitted entirely.
        return tuple(
            OverallBalance(currency=currency, net_amount_in_minor=amount)
            for currency, amount in sorted(totals.items())
        )

    async def get_group_net_balances(
        self,
        *,
        user_id: uuid.UUID,
        group_ids: Sequence[uuid.UUID],
    ) -> dict[uuid.UUID, int]:
        """One user's net balance (paid - share + settlements) in each of
        `group_ids`, computed with aggregate queries so a groups-list screen
        can show every row's balance without one debt-summary call per
        group. A group_id absent from the result has a net balance of 0.
        """
        if not group_ids:
            return {}

        totals: defaultdict[uuid.UUID, int] = defaultdict(int)

        paid_rows = await self.session.execute(
            select(
                GroupExpense.group_id,
                func.coalesce(func.sum(GroupExpense.total_amount_in_minor), 0),
            )
            .where(
                GroupExpense.group_id.in_(group_ids),
                GroupExpense.payer_user_id == user_id,
                GroupExpense.deleted_at.is_(None),
            )
            .group_by(GroupExpense.group_id)
        )
        for group_id, amount in paid_rows:
            totals[group_id] += amount

        share_rows = await self.session.execute(
            select(
                GroupExpense.group_id,
                func.coalesce(func.sum(ExpenseShare.amount_in_minor), 0),
            )
            .select_from(ExpenseShare)
            .join(GroupExpense, GroupExpense.id == ExpenseShare.expense_id)
            .where(
                GroupExpense.group_id.in_(group_ids),
                ExpenseShare.user_id == user_id,
                GroupExpense.deleted_at.is_(None),
            )
            .group_by(GroupExpense.group_id)
        )
        for group_id, amount in share_rows:
            totals[group_id] -= amount

        settlements_paid_rows = await self.session.execute(
            select(
                Settlement.group_id,
                func.coalesce(func.sum(Settlement.amount_in_minor), 0),
            )
            .where(
                Settlement.group_id.in_(group_ids),
                Settlement.from_user_id == user_id,
            )
            .group_by(Settlement.group_id)
        )
        for group_id, amount in settlements_paid_rows:
            totals[group_id] += amount

        settlements_received_rows = await self.session.execute(
            select(
                Settlement.group_id,
                func.coalesce(func.sum(Settlement.amount_in_minor), 0),
            )
            .where(
                Settlement.group_id.in_(group_ids),
                Settlement.to_user_id == user_id,
            )
            .group_by(Settlement.group_id)
        )
        for group_id, amount in settlements_received_rows:
            totals[group_id] -= amount

        return dict(totals)

    async def get_groups_with_activity(
        self,
        group_ids: Sequence[uuid.UUID],
    ) -> set[uuid.UUID]:
        """Which of `group_ids` have at least one non-deleted expense or one
        settlement (by anyone, not just the current user) — used to tell
        "settled_up" (net 0, but the group has history) apart from
        "no_expenses" (the group has never had any financial activity).
        """
        if not group_ids:
            return set()

        expense_group_ids = await self.session.execute(
            select(GroupExpense.group_id)
            .where(
                GroupExpense.group_id.in_(group_ids),
                GroupExpense.deleted_at.is_(None),
            )
            .distinct()
        )
        settlement_group_ids = await self.session.execute(
            select(Settlement.group_id)
            .where(Settlement.group_id.in_(group_ids))
            .distinct()
        )
        return {row[0] for row in expense_group_ids} | {
            row[0] for row in settlement_group_ids
        }
