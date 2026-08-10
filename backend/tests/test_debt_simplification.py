from itertools import permutations

import pytest

from app.domain.debts import (
    DebtBalance,
    DebtSimplificationService,
    DebtTransfer,
    InvalidDebtBalanceException,
)


def balance(user_id: str, amount: int) -> DebtBalance:
    return DebtBalance(user_id, user_id.title(), amount)


def test_simplifies_five_member_fixture_in_contract_order() -> None:
    balances = (
        balance("user-1", -12000),
        balance("user-2", -7000),
        balance("user-3", 7000),
        balance("user-4", 7000),
        balance("user-5", 5000),
    )

    assert DebtSimplificationService.simplify(balances) == (
        DebtTransfer("user-1", "user-3", 7000),
        DebtTransfer("user-2", "user-4", 7000),
        DebtTransfer("user-1", "user-5", 5000),
    )


def test_calculates_net_balance_from_paid_and_share_minor_units() -> None:
    assert DebtBalance.from_totals(
        user_id="alice",
        display_name="Alice",
        total_paid_in_minor=12_550,
        share_in_minor=10_000,
    ) == DebtBalance("alice", "Alice", 2_550)


def test_ignores_zero_balances_and_never_emits_zero_transfer() -> None:
    result = DebtSimplificationService.simplify(
        [balance("debtor", -1), balance("settled", 0), balance("creditor", 1)]
    )

    assert result == (DebtTransfer("debtor", "creditor", 1),)
    assert all(item.amount_in_minor > 0 for item in result)


def test_rejects_an_unbalanced_group_before_matching() -> None:
    with pytest.raises(InvalidDebtBalanceException, match="sum to exactly zero"):
        DebtSimplificationService.simplify(
            [balance("debtor", -100), balance("creditor", 99)]
        )


def test_rejects_duplicate_member_balances() -> None:
    with pytest.raises(InvalidDebtBalanceException, match="duplicate"):
        DebtSimplificationService.simplify(
            [balance("same", -10), balance("same", 10)]
        )


@pytest.mark.parametrize("invalid", [12.5, True, "1250"])
def test_rejects_non_integer_minor_currency(invalid: object) -> None:
    with pytest.raises(TypeError, match="must be an int"):
        DebtBalance("user", "User", invalid)  # type: ignore[arg-type]


def test_equal_balances_use_user_id_tie_breaker_for_every_input_order() -> None:
    balances = (
        balance("debtor-b", -100),
        balance("creditor-b", 100),
        balance("debtor-a", -100),
        balance("creditor-a", 100),
    )
    expected = (
        DebtTransfer("debtor-a", "creditor-a", 100),
        DebtTransfer("debtor-b", "creditor-b", 100),
    )

    for candidate in permutations(balances):
        assert DebtSimplificationService.simplify(candidate) == expected


def test_reprioritizes_partially_settled_members_after_every_transfer() -> None:
    result = DebtSimplificationService.simplify(
        [
            balance("debtor-1", -10),
            balance("debtor-2", -9),
            balance("creditor-1", 6),
            balance("creditor-2", 5),
            balance("creditor-3", 4),
            balance("creditor-4", 4),
        ]
    )

    assert result[:2] == (
        DebtTransfer("debtor-1", "creditor-1", 6),
        DebtTransfer("debtor-2", "creditor-2", 5),
    )


def test_generated_transfers_settle_every_member_exactly() -> None:
    balances = [
        balance("debtor-1", -12_345),
        balance("debtor-2", -7_655),
        balance("creditor-1", 11_111),
        balance("creditor-2", 8_889),
        balance("settled", 0),
    ]
    remaining = {item.user_id: item.net_amount_in_minor for item in balances}

    for transfer in DebtSimplificationService.simplify(balances):
        remaining[transfer.from_user_id] += transfer.amount_in_minor
        remaining[transfer.to_user_id] -= transfer.amount_in_minor

    assert set(remaining.values()) == {0}


def test_supports_large_integer_amounts_without_precision_loss() -> None:
    amount = 9_223_372_036_854_775_807

    assert DebtSimplificationService.simplify(
        [balance("debtor", -amount), balance("creditor", amount)]
    ) == (DebtTransfer("debtor", "creditor", amount),)


def test_empty_and_already_settled_groups_need_no_transfers() -> None:
    assert DebtSimplificationService.simplify([]) == ()
    assert DebtSimplificationService.simplify([balance("settled", 0)]) == ()
