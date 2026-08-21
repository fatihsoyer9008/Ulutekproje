import logging

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deep_link_pages import deep_link_landing_page
from app.api.dependencies import (
    get_current_user,
    get_email_sender,
    get_rate_limiter,
)
from app.core.database import get_db_session
from app.core.friend_invitation_rate_limits import (
    enforce_friend_invitation_rate_limits,
)
from app.core.rate_limit import RateLimiter
from app.core.security import normalize_email, privacy_hash
from app.friend_invitation_schemas import (
    FriendInvitationAcceptResponse,
    FriendInvitationCreateRequest,
    FriendInvitationRequestReceived,
)
from app.models.user import User
from app.services.email_service import EmailSender
from app.services.friend_invitation_service import (
    FriendInvitationError,
    FriendInvitationService,
)

router = APIRouter(tags=["friend-invitations"])
logger = logging.getLogger(__name__)


@router.post(
    "/api/v1/friends/invitations",
    response_model=FriendInvitationRequestReceived,
    status_code=status.HTTP_202_ACCEPTED,
)
async def create_friend_invitation(
    payload: FriendInvitationCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
    limiter: RateLimiter = Depends(get_rate_limiter),
    email_sender: EmailSender = Depends(get_email_sender),
) -> FriendInvitationRequestReceived:
    invited_email = normalize_email(str(payload.email))
    try:
        await enforce_friend_invitation_rate_limits(
            limiter=limiter,
            actor_user_id=user.id,
            invited_email=invited_email,
        )
    except HTTPException as error:
        if error.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": "invitation_rate_limited",
                    "message": "Çok fazla davet isteği gönderildi.",
                },
                headers=error.headers,
            ) from None
        raise

    service = FriendInvitationService(db)
    token, inviter_display_name = await service.create(
        actor_user_id=user.id,
        actor_display_name=user.display_name or user.email,
        invited_email=invited_email,
    )

    try:
        await email_sender.send_friend_invitation(
            email=invited_email,
            token=token,
            inviter_display_name=inviter_display_name,
        )
    except Exception as error:
        logger.error(
            "friend_invitation_delivery_failed actor_user_id=%s email_hash=%s "
            "error_type=%s",
            user.id,
            privacy_hash(invited_email),
            type(error).__name__,
        )

    return FriendInvitationRequestReceived()


@router.get(
    "/api/v1/friend-invitation",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def friend_invitation_landing_page(
    token: str = Query(min_length=1, max_length=512),
) -> HTMLResponse:
    return deep_link_landing_page(
        token=token,
        deep_link_path="friend-invitation",
        title="Arkadaşlık daveti",
        description="Daveti kabul etmek için EconBuddy uygulamasını aç.",
        button_label="Arkadaşlık davetini kabul et",
    )


@router.post(
    "/api/v1/friend-invitations/{token}/accept",
    response_model=FriendInvitationAcceptResponse,
    status_code=status.HTTP_201_CREATED,
)
async def accept_friend_invitation(
    token: str = Path(min_length=1, max_length=512),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> FriendInvitationAcceptResponse:
    try:
        friend = await FriendInvitationService(db).accept(token=token, user=user)
    except FriendInvitationError as error:
        _raise_invitation_error(error)

    return FriendInvitationAcceptResponse(friend=friend)


def _raise_invitation_error(error: FriendInvitationError) -> None:
    status_code, message = {
        "invitation_email_mismatch": (
            status.HTTP_403_FORBIDDEN,
            "Davet farklı bir doğrulanmış e-posta hesabına aittir.",
        ),
        "invitation_expired_or_used": (
            status.HTTP_410_GONE,
            "Davet süresi dolmuş veya daha önce kullanılmış.",
        ),
        "cannot_friend_self": (
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Kendinizle arkadaş olamazsınız.",
        ),
    }[error.code]
    raise HTTPException(
        status_code=status_code,
        detail={"code": error.code, "message": message},
    ) from None
