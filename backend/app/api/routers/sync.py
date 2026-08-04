from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.core.database import get_db_session
from app.models.user import User
from app.services.sync_service import InvalidSyncCursor, SyncService
from app.sync_schemas import (
    ClaimRequest,
    ClaimResponse,
    PullResponse,
    PushRequest,
    PushResponse,
)

router = APIRouter(prefix="/api/v1/sync", tags=["sync"])


@router.post("/claim", response_model=ClaimResponse)
async def claim_transactions(
    payload: ClaimRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ClaimResponse:
    return await SyncService(db).claim(
        user=user,
        installation_id=payload.installation_id,
        transactions=payload.transactions,
    )


@router.post("/push", response_model=PushResponse)
async def push_transactions(
    payload: PushRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PushResponse:
    return await SyncService(db).push(
        user=user,
        installation_id=payload.installation_id,
        operations=payload.operations,
    )


@router.get("/pull", response_model=PullResponse)
async def pull_transactions(
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PullResponse:
    try:
        return await SyncService(db).pull(
            user=user,
            cursor=cursor,
            limit=limit,
        )
    except InvalidSyncCursor:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid sync cursor.",
        ) from None
