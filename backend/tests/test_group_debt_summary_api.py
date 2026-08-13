from datetime import UTC, datetime

import pytest

from app.models import ExpenseSplitType
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.settlements import SettlementRepository
from tests.test_settlement_api import settlement_api_context

__all__ = ("settlement_api_context",)


async def _create_expense(
    context: dict[str, object],
    *,
    total: int = 10_000,
    deleted: bool = False,
) -> None:
    async with context["session_factory"]() as session:  # type: ignore[index,operator]
        repository = GroupExpenseRepository(session)
        expense = await repository.create(
            group_id=context["group_id"],  # type: ignore[arg-type]
            payer_user_id=context["owner"].id,  # type: ignore[union-attr]
            created_by_id=context["owner"].id,  # type: ignore[union-attr]
            title="Debt summary expense",
            expense_date=datetime(2026, 8, 13, tzinfo=UTC),
            total_amount_in_minor=total,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=(
                (context["owner"].id, total // 2),  # type: ignore[union-attr]
                (context["member"].id, total // 2),  # type: ignore[union-attr]
            ),
        )
        if deleted:
            await repository.soft_delete(expense, deleted_at=datetime.now(UTC))
        await session.commit()


@pytest.mark.asyncio
async def test_real_expense_and_settlement_are_reflected_in_summary(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    await _create_expense(context)

    async with context["session_factory"]() as session:
        await SettlementRepository(session).create(
            group_id=context["group_id"],
            from_user_id=context["member"].id,
            to_user_id=context["owner"].id,
            amount_in_minor=2_000,
            currency="TRY",
            settled_at=datetime(2026, 8, 13, 12, tzinfo=UTC),
            note=None,
        )
        await session.commit()

    response = await context["client"].get(
        f"/api/v1/groups/{context['group_id']}/debt-summary"
    )

    assert response.status_code == 200
    data = response.json()
    assert {
        item["user_id"]: item["net_amount_in_minor"] for item in data["balances"]
    } == {
        str(context["owner"].id): 3_000,
        str(context["member"].id): -3_000,
    }
    assert data["suggested_transfers"] == [
        {
            "from_user_id": str(context["member"].id),
            "to_user_id": str(context["owner"].id),
            "amount_in_minor": 3_000,
        }
    ]


@pytest.mark.asyncio
async def test_soft_deleted_expense_is_excluded(settlement_api_context) -> None:
    context = settlement_api_context
    await _create_expense(context, deleted=True)

    response = await context["client"].get(
        f"/api/v1/groups/{context['group_id']}/debt-summary"
    )

    assert response.status_code == 200
    assert all(
        item["net_amount_in_minor"] == 0 for item in response.json()["balances"]
    )
    assert response.json()["suggested_transfers"] == []


@pytest.mark.asyncio
async def test_non_member_gets_standard_group_forbidden(
    settlement_api_context,
) -> None:
    context = settlement_api_context
    context["current_user"]["value"] = context["outsider"]

    response = await context["client"].get(
        f"/api/v1/groups/{context['group_id']}/debt-summary"
    )

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "group_forbidden"


@pytest.mark.asyncio
async def test_empty_group_returns_active_members_with_zero_balances(
    settlement_api_context,
) -> None:
    context = settlement_api_context

    response = await context["client"].get(
        f"/api/v1/groups/{context['group_id']}/debt-summary"
    )

    assert response.status_code == 200
    data = response.json()
    assert {
        item["user_id"]: item["net_amount_in_minor"] for item in data["balances"]
    } == {
        str(context["owner"].id): 0,
        str(context["member"].id): 0,
    }
    assert data["suggested_transfers"] == []
