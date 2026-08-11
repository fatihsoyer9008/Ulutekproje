"""Pure domain models and deterministic debt simplification logic.

Money is represented exclusively as integer minor units.  This module has no
database, ORM, HTTP, or framework dependency.
"""

from dataclasses import dataclass
from datetime import datetime
from heapq import heapify, heappop, heappush
from typing import Iterable, Self


class InvalidDebtBalanceException(ValueError):
    """Raised when balances cannot represent a valid closed debt group."""


class DebtSimplificationInvariantException(RuntimeError):
    """Raised if a generated plan does not settle every member exactly."""


def _require_minor_unit(value: object, field_name: str) -> None:
    # bool is an int subclass in Python, but is never a valid monetary amount.
    if type(value) is not int:
        raise TypeError(f"{field_name} must be an int in minor currency units")


def _require_user_id(value: str, field_name: str) -> None:
    if not isinstance(value, str) or not value:
        raise ValueError(f"{field_name} must be a non-empty string")


@dataclass(frozen=True, slots=True)
class DebtBalance:
    """A member's net balance: total paid minus the member's share."""

    user_id: str
    display_name: str
    net_amount_in_minor: int

    def __post_init__(self) -> None:
        _require_user_id(self.user_id, "user_id")
        _require_minor_unit(self.net_amount_in_minor, "net_amount_in_minor")

    @classmethod
    def from_totals(
        cls,
        *,
        user_id: str,
        display_name: str,
        total_paid_in_minor: int,
        share_in_minor: int,
    ) -> Self:
        """Calculate ``net = total paid - share`` using minor-unit integers."""
        _require_minor_unit(total_paid_in_minor, "total_paid_in_minor")
        _require_minor_unit(share_in_minor, "share_in_minor")
        if total_paid_in_minor < 0 or share_in_minor < 0:
            raise ValueError("paid and share amounts cannot be negative")
        return cls(
            user_id=user_id,
            display_name=display_name,
            net_amount_in_minor=total_paid_in_minor - share_in_minor,
        )


@dataclass(frozen=True, slots=True)
class DebtTransfer:
    """A positive payment from a debtor to a creditor."""

    from_user_id: str
    to_user_id: str
    amount_in_minor: int

    def __post_init__(self) -> None:
        _require_user_id(self.from_user_id, "from_user_id")
        _require_user_id(self.to_user_id, "to_user_id")
        _require_minor_unit(self.amount_in_minor, "amount_in_minor")
        if self.from_user_id == self.to_user_id:
            raise ValueError("a debt transfer cannot be made to the same user")
        if self.amount_in_minor <= 0:
            raise ValueError("amount_in_minor must be greater than zero")


@dataclass(frozen=True, slots=True)
class DebtSummary:
    """Framework-independent snapshot matching the Task 3.1 API contract."""

    group_id: str
    currency: str
    balances: tuple[DebtBalance, ...]
    suggested_transfers: tuple[DebtTransfer, ...]
    generated_at: datetime


class DebtSimplificationService:
    """Create a deterministic greedy settlement plan from net balances.

    Let ``n`` be the member count. Heap construction is O(n). Every transfer
    settles at least one side and performs at most two O(log n) heap updates,
    so matching and total time are O(n log n). Auxiliary space is O(n), and at
    most ``debtors + creditors - 1`` transfers are emitted for a non-empty
    group.

    Heap priority uses descending remaining balance and ascending ``user_id``
    as the deterministic tie-breaker. Inputs are never mutated.
    """

    @staticmethod
    def simplify(balances: Iterable[DebtBalance]) -> tuple[DebtTransfer, ...]:
        """Return payments that settle all non-zero balances exactly.

        ``net_amount_in_minor`` is expected to already represent
        ``total paid - member share`` as defined by ``DebtBalance``. A negative
        member pays; a positive member receives. All arithmetic remains integer
        minor-unit arithmetic, so no rounding or precision loss is possible.
        """
        materialized = tuple(balances)
        DebtSimplificationService._validate(materialized)

        # Python's heap is a min-heap; negative amounts make the largest open
        # balance the next item. user_id is the deterministic secondary key.
        debtors = [
            (balance.net_amount_in_minor, balance.user_id)
            for balance in materialized
            if balance.net_amount_in_minor < 0
        ]
        creditors = [
            (-balance.net_amount_in_minor, balance.user_id)
            for balance in materialized
            if balance.net_amount_in_minor > 0
        ]
        heapify(debtors)
        heapify(creditors)

        transfers: list[DebtTransfer] = []
        while debtors and creditors:
            negative_debt, debtor_user_id = heappop(debtors)
            negative_credit, creditor_user_id = heappop(creditors)
            debt = -negative_debt
            credit = -negative_credit
            amount = min(debt, credit)
            transfers.append(
                DebtTransfer(
                    from_user_id=debtor_user_id,
                    to_user_id=creditor_user_id,
                    amount_in_minor=amount,
                )
            )
            remaining_debt = debt - amount
            remaining_credit = credit - amount
            if remaining_debt:
                heappush(debtors, (-remaining_debt, debtor_user_id))
            if remaining_credit:
                heappush(creditors, (-remaining_credit, creditor_user_id))

        result = tuple(transfers)
        DebtSimplificationService._validate_result(materialized, result)
        return result

    @staticmethod
    def _validate(balances: tuple[DebtBalance, ...]) -> None:
        seen_user_ids: set[str] = set()
        total = 0
        for balance in balances:
            if not isinstance(balance, DebtBalance):
                raise TypeError("balances must contain only DebtBalance values")
            if balance.user_id in seen_user_ids:
                raise InvalidDebtBalanceException(
                    f"duplicate balance for user_id: {balance.user_id}"
                )
            seen_user_ids.add(balance.user_id)
            total += balance.net_amount_in_minor

        if total != 0:
            raise InvalidDebtBalanceException(
                "net debt balance must sum to exactly zero minor units; "
                f"received {total}"
            )

    @staticmethod
    def _validate_result(
        balances: tuple[DebtBalance, ...],
        transfers: tuple[DebtTransfer, ...],
    ) -> None:
        """Assert that applying the plan settles every balance exactly."""
        remaining = {
            balance.user_id: balance.net_amount_in_minor for balance in balances
        }
        for transfer in transfers:
            if (
                transfer.from_user_id not in remaining
                or transfer.to_user_id not in remaining
            ):
                raise DebtSimplificationInvariantException(
                    "generated transfer references a user outside the group"
                )
            remaining[transfer.from_user_id] += transfer.amount_in_minor
            remaining[transfer.to_user_id] -= transfer.amount_in_minor

        unsettled = {user_id: amount for user_id, amount in remaining.items() if amount}
        if unsettled:
            raise DebtSimplificationInvariantException(
                f"generated transfers do not settle every balance: {unsettled}"
            )
