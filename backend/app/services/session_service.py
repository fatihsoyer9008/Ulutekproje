import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    generate_opaque_token,
    hash_token,
    privacy_hash,
    utc_now,
)
from app.models.refresh_session import RefreshSession
from app.models.user import User, UserStatus
from app.repositories.sessions import SessionRepository
from app.repositories.users import UserRepository


class InvalidRefreshToken(ValueError):
    pass


class RefreshTokenReuseDetected(InvalidRefreshToken):
    pass


@dataclass(frozen=True)
class SessionMetadata:
    ip_address: str
    user_agent: str | None = None
    device_id: str | None = None
    device_name: str | None = None


@dataclass(frozen=True)
class IssuedSession:
    access_token: str
    refresh_token: str
    expires_in: int
    user: User


class SessionService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.sessions = SessionRepository(db)
        self.users = UserRepository(db)

    async def issue(
        self,
        *,
        user: User,
        metadata: SessionMetadata,
        family_id: uuid.UUID | None = None,
        parent_session_id: uuid.UUID | None = None,
    ) -> IssuedSession:
        plaintext = generate_opaque_token()
        now = utc_now()
        refresh_session = RefreshSession(
            id=uuid.uuid4(),
            user_id=user.id,
            family_id=family_id or uuid.uuid4(),
            parent_session_id=parent_session_id,
            token_hash=hash_token(plaintext),
            issued_at=now,
            expires_at=now + timedelta(days=settings.refresh_token_days),
            device_id_hash=(
                privacy_hash(metadata.device_id) if metadata.device_id else None
            ),
            device_name=metadata.device_name,
            ip_hash=privacy_hash(metadata.ip_address),
            user_agent=metadata.user_agent,
        )
        await self.sessions.add(refresh_session)
        access_token, expires_in = create_access_token(
            user_id=user.id,
            session_id=refresh_session.id,
            auth_version=user.auth_version,
        )
        return IssuedSession(
            access_token=access_token,
            refresh_token=plaintext,
            expires_in=expires_in,
            user=user,
        )

    async def rotate(
        self,
        *,
        refresh_token: str,
        metadata: SessionMetadata,
    ) -> IssuedSession:
        now = utc_now()
        current = await self.sessions.get_by_hash_for_update(
            hash_token(refresh_token)
        )
        if current is None:
            raise InvalidRefreshToken("Invalid refresh token")

        user = await self.users.get_by_id(current.user_id)
        if user is None or user.status is not UserStatus.active:
            raise InvalidRefreshToken("Invalid refresh token")

        if current.revoked_at is not None:
            if current.reuse_detected_at is None:
                current.reuse_detected_at = now
                user.auth_version += 1
            await self.sessions.revoke_family(
                current.family_id,
                revoked_at=now,
                reuse_detected_at=now,
            )
            await self.db.commit()
            raise RefreshTokenReuseDetected("Refresh token reuse detected")

        if _as_utc(current.expires_at) <= now:
            current.revoked_at = now
            await self.db.commit()
            raise InvalidRefreshToken("Expired refresh token")

        current.revoked_at = now
        current.last_used_at = now
        issued = await self.issue(
            user=user,
            metadata=metadata,
            family_id=current.family_id,
            parent_session_id=current.id,
        )

        replacement_hash = hash_token(issued.refresh_token)
        replacement = await self.sessions.get_by_hash_for_update(
            replacement_hash
        )
        if replacement is None:
            raise RuntimeError("Replacement refresh session was not persisted")
        current.replaced_by_session_id = replacement.id
        user.last_login_at = now
        await self.db.commit()
        return issued

    async def logout(
        self,
        *,
        refresh_token: str,
        all_devices: bool,
    ) -> None:
        now = utc_now()
        current = await self.sessions.get_by_hash_for_update(
            hash_token(refresh_token)
        )
        if current is None:
            return

        if all_devices:
            user = await self.users.get_by_id(current.user_id)
            if user is not None:
                user.auth_version += 1
            await self.sessions.revoke_user_sessions(
                current.user_id,
                revoked_at=now,
            )
        elif current.revoked_at is None:
            current.revoked_at = now
        await self.db.commit()

    async def revoke_all_for_user(self, user: User) -> None:
        now = utc_now()
        user.auth_version += 1
        await self.sessions.revoke_user_sessions(user.id, revoked_at=now)


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
