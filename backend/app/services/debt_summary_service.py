import uuid
from collections import defaultdict
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.debts import (
    DebtBalance,
    DebtSimplificationService,
    DebtSummary,
    DebtTransfer,
)
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
        financial_user_ids: set[uuid.UUID] = set()

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
