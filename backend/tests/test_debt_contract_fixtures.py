import json
from pathlib import Path

import pytest

from app.domain.debts import (
    DebtBalance,
    DebtSimplificationService,
    DebtTransfer,
)

_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
_FIXTURE_ROOT = _REPOSITORY_ROOT / "docs" / "fixtures" / "group_debts"


def _read_fixture(file_name: str) -> dict[str, object]:
    with (_FIXTURE_ROOT / file_name).open(encoding="utf-8") as fixture_file:
        return json.load(fixture_file)


def _settled_balances(input_data: dict[str, object]) -> dict[str, int]:
    balances = {
        item["user_id"]: item["net_amount_in_minor"]
        for item in input_data["expense_balances"]
    }
    for settlement in input_data["settlements"]:
        amount = settlement["amount_in_minor"]
        balances[settlement["from_user_id"]] += amount
        balances[settlement["to_user_id"]] -= amount
    return balances


@pytest.mark.parametrize("member_count", [2, 3, 5])
def test_contract_fixture_matches_debt_simplification_output(
    member_count: int,
) -> None:
    input_data = _read_fixture(f"debt_algorithm_input_{member_count}_members.json")
    summary = _read_fixture(f"debt_summary_{member_count}_members.json")
    settled_balances = _settled_balances(input_data)
    display_names = {
        item["user_id"]: item["display_name"] for item in summary["balances"]
    }

    balances = tuple(
        DebtBalance(
            user_id=user_id,
            display_name=display_names[user_id],
            net_amount_in_minor=amount,
        )
        for user_id, amount in settled_balances.items()
    )
    expected_transfers = tuple(
        DebtTransfer(
            from_user_id=item["from_user_id"],
            to_user_id=item["to_user_id"],
            amount_in_minor=item["amount_in_minor"],
        )
        for item in summary["suggested_transfers"]
    )

    assert {item.user_id: item.net_amount_in_minor for item in balances} == {
        item["user_id"]: item["net_amount_in_minor"]
        for item in summary["balances"]
    }
    assert DebtSimplificationService.simplify(balances) == expected_transfers
