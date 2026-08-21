import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    generate_opaque_token,
    hash_token,
    normalize_email,
    utc_now,
)
from app.friend_schemas import FriendEntry
from app.models.user import User
from app.repositories.friend_invitations import FriendInvitationRepository
from app.repositories.users import UserRepository
from app.services.friend_service import FriendService
from app.services.group_service import GroupService, GroupServiceError

FRIEND_INVITATION_LIFETIME = timedelta(hours=24)


class FriendInvitationError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class FriendInvitationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.invitations = FriendInvitationRepository(session)
        self.users = UserRepository(session)
        self.groups = GroupService(session)
        self.friends = FriendService(session)

    async def create(
        self,
        *,
        actor_user_id: uuid.UUID,
        actor_display_name: str,
        invited_email: str,
    ) -> tuple[str, str]:
        normalized_email = normalize_email(invited_email)
        token = generate_opaque_token()
        await self.invitations.create(
            invited_email=normalized_email,
            invited_by_user_id=actor_user_id,
            token_hash=hash_token(token),
            expires_at=utc_now() + FRIEND_INVITATION_LIFETIME,
        )
        await self.session.commit()
        return token, actor_display_name

    async def accept(
        self,
        *,
        token: str,
        user: User,
    ) -> FriendEntry:
        invitation = await self.invitations.get_by_token_hash(
            hash_token(token),
            for_update=True,
        )
        now = utc_now()
        if (
            invitation is None
            or invitation.accepted_at is not None
            or invitation.invited_by_user_id is None
            or _as_utc(invitation.expires_at) <= now
        ):
            raise FriendInvitationError("invitation_expired_or_used")

        if (
            not user.is_email_verified
            or normalize_email(user.email) != invitation.invited_email
        ):
            raise FriendInvitationError("invitation_email_mismatch")

        inviter_id = invitation.invited_by_user_id
        if await self.users.get_by_id(inviter_id) is None:
            raise FriendInvitationError("invitation_expired_or_used")

        try:
            group = await self.groups.get_or_create_direct_group(
                user_a_id=inviter_id,
                user_b_id=user.id,
            )
        except GroupServiceError as error:
            if error.code == "cannot_friend_self":
                raise FriendInvitationError("cannot_friend_self") from None
            raise FriendInvitationError("invitation_expired_or_used") from None

        invitation.accepted_at = now
        invitation.accepted_by_user_id = user.id
        await self.session.commit()

        friends = await self.friends.list_friends(user.id)
        entry = next(
            (friend for friend in friends if friend.direct_group_id == group.id),
            None,
        )
        if entry is None:  # pragma: no cover - database invariant guard
            raise RuntimeError("accepted friend invitation is missing its entry")
        return entry


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
