import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_debt_summary_cache
from app.api.routers.groups import create_expense_for_group
from app.core.database import get_db_session
from app.friend_schemas import FriendsResponse
from app.group_schemas import (
    GroupExpenseCreateRequest,
    GroupExpenseEnvelope,
    ItemizedExpenseCreateRequest,
)
from app.models.user import User
from app.services.debt_summary_cache import DebtSummaryCache
from app.services.friend_service import FriendService
from app.services.group_service import GroupService, GroupServiceError

router = APIRouter(prefix="/api/v1/friends", tags=["friends"])

_FRIEND_ERRORS = {
    "cannot_friend_self": (
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        "Kendinizle arkadaş olamazsınız.",
    ),
    "user_not_found": (status.HTTP_404_NOT_FOUND, "Kullanıcı bulunamadı."),
}


@router.get("", response_model=FriendsResponse)
async def list_friends(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> FriendsResponse:
    friends = await FriendService(db).list_friends(user.id)
    return FriendsResponse(friends=friends)


@router.post(
    "/{friend_user_id}/expenses",
    response_model=GroupExpenseEnvelope,
    status_code=status.HTTP_201_CREATED,
)
async def create_friend_expense(
    friend_user_id: uuid.UUID,
    payload: GroupExpenseCreateRequest | ItemizedExpenseCreateRequest,
    response: Response,
    user: User = Depends(get_current_user),
    idempotency_key: str = Header(
        alias="Idempotency-Key",
        min_length=8,
        max_length=128,
    ),
    db: AsyncSession = Depends(get_db_session),
    debt_cache: DebtSummaryCache = Depends(get_debt_summary_cache),
) -> GroupExpenseEnvelope:
    try:
        group = await GroupService(db).get_or_create_direct_group(
            user_a_id=user.id,
            user_b_id=friend_user_id,
        )
    except GroupServiceError as error:
        status_code, message = _FRIEND_ERRORS[error.code]
        raise HTTPException(
            status_code=status_code,
            detail={"code": error.code, "message": message},
        ) from None

    return await create_expense_for_group(
        group_id=group.id,
        actor_user_id=user.id,
        payload=payload,
        response=response,
        idempotency_key=idempotency_key,
        db=db,
        debt_cache=debt_cache,
    )
