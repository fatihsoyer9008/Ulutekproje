from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.database import get_db_session
from app.me_schemas import BalanceSummaryResponse
from app.models.user import User
from app.services.debt_summary_service import DebtSummaryService

router = APIRouter(prefix="/api/v1/me", tags=["me"])


@router.get("/balance-summary", response_model=BalanceSummaryResponse)
async def get_balance_summary(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> BalanceSummaryResponse:
    balances = await DebtSummaryService(db).get_overall_balance(user.id)
    return BalanceSummaryResponse.from_domain(balances)
