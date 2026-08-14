import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Path, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    get_debt_summary_cache,
    get_email_sender,
    get_rate_limiter,
    require_group_admin,
)
from app.core.database import get_db_session
from app.core.group_invitation_rate_limits import (
    enforce_group_invitation_rate_limits,
)
from app.core.rate_limit import RateLimiter
from app.core.security import normalize_email, privacy_hash
from app.group_invitation_schemas import (
    GroupInvitationCreateRequest,
    GroupInvitationRequestReceived,
)
from app.group_schemas import GroupMemberEnvelope
from app.models.group import GroupMember
from app.models.user import User
from app.services.debt_summary_cache import DebtSummaryCache
from app.services.email_service import EmailSender
from app.services.group_invitation_service import (
    GroupInvitationError,
    GroupInvitationService,
)

router = APIRouter(tags=["group-invitations"])
logger = logging.getLogger(__name__)


@router.post(
    "/api/v1/groups/{group_id}/invitations",
    response_model=GroupInvitationRequestReceived,
    status_code=status.HTTP_202_ACCEPTED,
)
async def create_group_invitation(
    group_id: uuid.UUID,
    payload: GroupInvitationCreateRequest,
    actor_membership: GroupMember = Depends(require_group_admin),
    db: AsyncSession = Depends(get_db_session),
    limiter: RateLimiter = Depends(get_rate_limiter),
    email_sender: EmailSender = Depends(get_email_sender),
) -> GroupInvitationRequestReceived:
    invited_email = normalize_email(str(payload.email))
    try:
        await enforce_group_invitation_rate_limits(
            limiter=limiter,
            actor_user_id=actor_membership.user_id,
            group_id=group_id,
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

    service = GroupInvitationService(db)
    try:
        token, group_name = await service.create(
            group_id=group_id,
            actor_user_id=actor_membership.user_id,
            actor_role=actor_membership.role,
            invited_email=invited_email,
            role=payload.role,
        )
    except GroupInvitationError as error:
        _raise_invitation_error(error)

    try:
        await email_sender.send_group_invitation(
            email=invited_email,
            token=token,
            group_name=group_name,
        )
    except Exception as error:
        logger.error(
            "group_invitation_delivery_failed group_id=%s email_hash=%s "
            "error_type=%s",
            group_id,
            privacy_hash(invited_email),
            type(error).__name__,
        )

    return GroupInvitationRequestReceived()


@router.post(
    "/api/v1/group-invitations/{token}/accept",
    response_model=GroupMemberEnvelope,
    status_code=status.HTTP_201_CREATED,
)
async def accept_group_invitation(
    token: str = Path(min_length=1, max_length=512),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
    debt_cache: DebtSummaryCache = Depends(get_debt_summary_cache),
) -> GroupMemberEnvelope:
    try:
        member = await GroupInvitationService(db).accept(token=token, user=user)
    except GroupInvitationError as error:
        _raise_invitation_error(error)

    await debt_cache.invalidate_best_effort(member.group_id)
    return GroupMemberEnvelope(member=member)


def _raise_invitation_error(error: GroupInvitationError) -> None:
    status_code, message = {
        "group_not_found": (
            status.HTTP_404_NOT_FOUND,
            "Grup bulunamadı.",
        ),
        "group_forbidden": (
            status.HTTP_403_FORBIDDEN,
            "Bu grup için yetkiniz yok.",
        ),
        "invitation_email_mismatch": (
            status.HTTP_403_FORBIDDEN,
            "Davet farklı bir doğrulanmış e-posta hesabına aittir.",
        ),
        "invitation_expired_or_used": (
            status.HTTP_410_GONE,
            "Davet süresi dolmuş veya daha önce kullanılmış.",
        ),
        "member_already_exists": (
            status.HTTP_409_CONFLICT,
            "Kullanıcı zaten grubun üyesi.",
        ),
    }[error.code]
    raise HTTPException(
        status_code=status_code,
        detail={"code": error.code, "message": message},
    ) from None
