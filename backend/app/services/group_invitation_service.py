import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    generate_opaque_token,
    hash_token,
    normalize_email,
    utc_now,
)
from app.group_schemas import GroupMemberResponse
from app.models.group import GroupRole
from app.models.user import User
from app.repositories.group_invitations import GroupInvitationRepository
from app.repositories.groups import GroupMemberAlreadyExists, GroupRepository

GROUP_INVITATION_LIFETIME = timedelta(hours=24)


class GroupInvitationError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class GroupInvitationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.invitations = GroupInvitationRepository(session)
        self.groups = GroupRepository(session)

    async def create(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        actor_role: GroupRole,
        invited_email: str,
        role: GroupRole,
    ) -> tuple[str, str]:
        if actor_role not in {GroupRole.owner, GroupRole.admin} or role is GroupRole.owner or (
            actor_role is GroupRole.admin and role is not GroupRole.member
        ):
            raise GroupInvitationError("group_forbidden")

        group = await self.groups.get_by_id(group_id)
        if group is None or group.archived_at is not None:
            raise GroupInvitationError("group_not_found")

        token = generate_opaque_token()
        await self.invitations.create(
            group_id=group_id,
            invited_email=normalize_email(invited_email),
            role=role,
            invited_by_user_id=actor_user_id,
            token_hash=hash_token(token),
            expires_at=utc_now() + GROUP_INVITATION_LIFETIME,
        )
        await self.session.commit()
        return token, group.name

    async def accept(
        self,
        *,
        token: str,
        user: User,
    ) -> GroupMemberResponse:
        invitation = await self.invitations.get_by_token_hash(
            hash_token(token),
            for_update=True,
        )
        now = utc_now()
        if (
            invitation is None
            or invitation.accepted_at is not None
            or _as_utc(invitation.expires_at) <= now
        ):
            raise GroupInvitationError("invitation_expired_or_used")

        if (
            not user.is_email_verified
            or normalize_email(user.email) != invitation.invited_email
        ):
            raise GroupInvitationError("invitation_email_mismatch")

        group = await self.groups.get_by_id(invitation.group_id)
        if group is None or group.archived_at is not None:
            raise GroupInvitationError("invitation_expired_or_used")

        try:
            membership = await self.groups.add_member(
                group_id=invitation.group_id,
                user_id=user.id,
                role=invitation.role,
                joined_at=now,
            )
        except GroupMemberAlreadyExists:
            raise GroupInvitationError("member_already_exists") from None

        invitation.accepted_at = now
        invitation.accepted_by_user_id = user.id
        await self.session.commit()
        return GroupMemberResponse(
            group_id=membership.group_id,
            user_id=membership.user_id,
            display_name=user.display_name or "Kullanıcı",
            role=membership.role,
            joined_at=_as_utc(membership.joined_at),
            left_at=None,
        )


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
