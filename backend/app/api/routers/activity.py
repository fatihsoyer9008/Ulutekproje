from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.activity_schemas import ActivityFeedResponse, ActivityItemResponse
from app.api.dependencies import get_current_user
from app.core.database import get_db_session
from app.models.user import User
from app.repositories.activity_log import (
    ActivityLogRepository,
    InvalidActivityCursor,
    decode_activity_cursor,
    encode_activity_cursor,
)

router = APIRouter(prefix="/api/v1/activity", tags=["activity"])

_DEFAULT_LIMIT = 20
_MAX_LIMIT = 50


@router.get("", response_model=ActivityFeedResponse)
async def list_activity(
    limit: int = Query(default=_DEFAULT_LIMIT, ge=1, le=_MAX_LIMIT),
    before: str | None = Query(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ActivityFeedResponse:
    if before is None:
        offset = 0
    else:
        try:
            offset = decode_activity_cursor(before)
        except InvalidActivityCursor:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "code": "invalid_cursor",
                    "message": "Geçersiz sayfalama anahtarı.",
                },
            ) from None

    repository = ActivityLogRepository(db)
    # Fetch one extra row to know whether a next page exists.
    rows = await repository.list_for_user(user.id, limit=limit + 1, offset=offset)

    has_more = len(rows) > limit
    page = rows[:limit]
    next_cursor = encode_activity_cursor(offset + limit) if has_more else None
    return ActivityFeedResponse(
        items=[
            ActivityItemResponse.from_model(activity, viewer_id=user.id)
            for activity in page
        ],
        next_cursor=next_cursor,
    )
