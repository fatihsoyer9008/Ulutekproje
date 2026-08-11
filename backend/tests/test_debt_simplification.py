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


def balances_from_expenses(
    member_ids: tuple[str, ...],
    expenses: tuple[tuple[str, int, dict[str, int]], ...],
) -> tuple[DebtBalance, ...]:
    """Aggregate paid/share amounts without introducing database models."""
    paid = dict.fromkeys(member_ids, 0)
    shares = dict.fromkeys(member_ids, 0)

    for payer_id, amount_in_minor, expense_shares in expenses:
        assert payer_id in paid
        assert set(expense_shares).issubset(paid)
        assert sum(expense_shares.values()) == amount_in_minor
        paid[payer_id] += amount_in_minor
        for user_id, share_in_minor in expense_shares.items():
            shares[user_id] += share_in_minor

    return tuple(
        DebtBalance.from_totals(
            user_id=user_id,
            display_name=user_id.title(),
            total_paid_in_minor=paid[user_id],
            share_in_minor=shares[user_id],
        )
        for user_id in member_ids
    )


def apply_settlement(
    balances: tuple[DebtBalance, ...],
    settlement: DebtTransfer,
) -> tuple[DebtBalance, ...]:
    """Apply an already-recorded payment before simplifying the remainder."""
    amounts = {item.user_id: item.net_amount_in_minor for item in balances}
    amounts[settlement.from_user_id] += settlement.amount_in_minor
    amounts[settlement.to_user_id] -= settlement.amount_in_minor
    return tuple(
        balance(item.user_id, amounts[item.user_id]) for item in balances
    )


def test_two_members_settle_one_equally_shared_expense() -> None:
    balances = balances_from_expenses(
        ("alice", "bob"),
        (("alice", 10_000, {"alice": 5_000, "bob": 5_000}),),
    )

    assert balances == (
        balance("alice", 5_000),
        balance("bob", -5_000),
    )
    assert DebtSimplificationService.simplify(balances) == (
        DebtTransfer("bob", "alice", 5_000),
    )


def test_three_members_simplify_cross_debts_to_net_transfers() -> None:
    # Alice owes Bob 4_000 and Bob owes Carol 3_000. Netting the shared member
    # avoids forwarding the same money through Bob.
    balances = (
        balance("alice", -4_000),
        balance("bob", 1_000),
        balance("carol", 3_000),
    )

    assert DebtSimplificationService.simplify(balances) == (
        DebtTransfer("alice", "carol", 3_000),
        DebtTransfer("alice", "bob", 1_000),
    )


def test_multiple_expenses_with_different_payers_use_aggregate_balances() -> None:
    balances = balances_from_expenses(
        ("alice", "bob", "carol"),
        (
            ("alice", 12_000, {"alice": 4_000, "bob": 4_000, "carol": 4_000}),
            ("bob", 9_000, {"alice": 3_000, "bob": 3_000, "carol": 3_000}),
        ),
    )

    assert balances == (
        balance("alice", 5_000),
        balance("bob", 2_000),
        balance("carol", -7_000),
    )
    assert DebtSimplificationService.simplify(balances) == (
        DebtTransfer("carol", "alice", 5_000),
        DebtTransfer("carol", "bob", 2_000),
    )


def test_minor_unit_remainder_is_settled_without_rounding_loss() -> None:
    balances = balances_from_expenses(
        ("alice", "bob", "carol"),
        (("alice", 1_001, {"alice": 333, "bob": 334, "carol": 334}),),
    )

    assert balances == (
        balance("alice", 668),
        balance("bob", -334),
        balance("carol", -334),
    )
    assert DebtSimplificationService.simplify(balances) == (
        DebtTransfer("bob", "alice", 334),
        DebtTransfer("carol", "alice", 334),
    )


def test_every_member_already_settled_emits_no_transfer() -> None:
    balances = (
        balance("alice", 0),
        balance("bob", 0),
        balance("carol", 0),
    )

    assert DebtSimplificationService.simplify(balances) == ()


def test_recorded_settlement_reduces_the_remaining_balance() -> None:
    expense_balances = (
        balance("creditor", 6_250),
        balance("debtor", -6_250),
    )
    balances_after_settlement = apply_settlement(
        expense_balances,
        DebtTransfer("debtor", "creditor", 2_500),
    )

    assert balances_after_settlement == (
        balance("creditor", 3_750),
        balance("debtor", -3_750),
    )
    assert DebtSimplificationService.simplify(balances_after_settlement) == (
        DebtTransfer("debtor", "creditor", 3_750),
    )


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


@pytest.mark.parametrize(
    ("total_paid_in_minor", "share_in_minor"),
    [(-1, 0), (0, -1)],
)
def test_rejects_negative_paid_or_share_input(
    total_paid_in_minor: int,
    share_in_minor: int,
) -> None:
    with pytest.raises(ValueError, match="cannot be negative"):
        DebtBalance.from_totals(
            user_id="user",
            display_name="User",
            total_paid_in_minor=total_paid_in_minor,
            share_in_minor=share_in_minor,
        )


@pytest.mark.parametrize("user_id", ["", None, 42])
def test_rejects_invalid_balance_user_id(user_id: object) -> None:
    with pytest.raises(ValueError, match="non-empty string"):
        DebtBalance(user_id, "User", 0)  # type: ignore[arg-type]


@pytest.mark.parametrize("amount_in_minor", [0, -1])
def test_rejects_non_positive_debt_transfer(amount_in_minor: int) -> None:
    with pytest.raises(ValueError, match="greater than zero"):
        DebtTransfer("debtor", "creditor", amount_in_minor)


def test_rejects_transfer_to_the_same_member() -> None:
    with pytest.raises(ValueError, match="same user"):
        DebtTransfer("user", "user", 1)


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
