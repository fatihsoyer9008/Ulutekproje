import uuid
from datetime import timedelta

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    DUMMY_PASSWORD_HASH,
    generate_opaque_token,
    hash_password,
    hash_token,
    normalize_email,
    password_needs_rehash,
    utc_now,
    verify_password,
)
from app.models.one_time_token import OneTimeToken, OneTimeTokenPurpose
from app.models.user import User, UserStatus
from app.repositories.sessions import SessionRepository
from app.repositories.tokens import OneTimeTokenRepository
from app.repositories.users import UserRepository
from app.services.email_service import EmailSender
from app.services.session_service import IssuedSession, SessionMetadata, SessionService


class InvalidCredentials(ValueError):
    pass


class InvalidOneTimeToken(ValueError):
    pass


class ReauthenticationRequired(ValueError):
    pass


class AuthService:
    def __init__(self, db: AsyncSession, email_sender: EmailSender) -> None:
        self.db = db
        self.email_sender = email_sender
        self.users = UserRepository(db)
        self.tokens = OneTimeTokenRepository(db)
        self.sessions = SessionRepository(db)

    async def register(
        self,
        *,
        email: str,
        password: str,
        display_name: str | None,
    ) -> None:
        normalized_email = normalize_email(email)
        existing = await self.users.get_by_email(normalized_email)
        if existing is not None:
            # Keep the expensive path similar without modifying the account.
            hash_password(password)
            return

        user = User(
            id=uuid.uuid4(),
            email=normalized_email,
            password_hash=hash_password(password),
            display_name=display_name,
            is_email_verified=False,
            status=UserStatus.active,
            auth_version=1,
        )
        try:
            await self.users.add(user)
            plaintext = await self._create_one_time_token(
                user=user,
                purpose=OneTimeTokenPurpose.verify_email,
                lifetime=timedelta(hours=24),
            )
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            return

        await self.email_sender.send_verification(
            email=user.email,
            token=plaintext,
        )

    async def login(
        self,
        *,
        email: str,
        password: str,
        metadata: SessionMetadata,
    ) -> IssuedSession:
        user = await self.users.get_by_email(normalize_email(email))
        candidate_hash = (
            user.password_hash
            if user is not None and user.password_hash is not None
            else DUMMY_PASSWORD_HASH
        )
        valid = verify_password(candidate_hash, password)

        if (
            user is None
            or user.password_hash is None
            or not valid
            or user.status is not UserStatus.active
        ):
            raise InvalidCredentials("Invalid email or password")

        if password_needs_rehash(user.password_hash):
            user.password_hash = hash_password(password)

        user.last_login_at = utc_now()
        issued = await SessionService(self.db).issue(
            user=user,
            metadata=metadata,
        )
        await self.db.commit()
        return issued

    async def verify_email(self, token: str) -> None:
        now = utc_now()
        record = await self.tokens.consume_active_for_update(
            token_hash=hash_token(token),
            purpose=OneTimeTokenPurpose.verify_email,
            now=now,
        )
        if record is None:
            raise InvalidOneTimeToken("Invalid or expired verification token")

        user = await self.users.get_by_id(record.user_id)
        if user is None:
            raise InvalidOneTimeToken("Invalid or expired verification token")

        record.consumed_at = now
        user.is_email_verified = True
        await self.db.commit()

    async def resend_verification(self, email: str) -> None:
        user = await self.users.get_by_email(normalize_email(email))
        if user is None or user.is_email_verified:
            return

        plaintext = await self._create_one_time_token(
            user=user,
            purpose=OneTimeTokenPurpose.verify_email,
            lifetime=timedelta(hours=24),
        )
        await self.db.commit()
        await self.email_sender.send_verification(
            email=user.email,
            token=plaintext,
        )

    async def forgot_password(self, email: str) -> None:
        user = await self.users.get_by_email(normalize_email(email))
        if user is None or user.password_hash is None:
            return

        plaintext = await self._create_one_time_token(
            user=user,
            purpose=OneTimeTokenPurpose.reset_password,
            lifetime=timedelta(minutes=30),
        )
        await self.db.commit()
        await self.email_sender.send_password_reset(
            email=user.email,
            token=plaintext,
        )

    async def reset_password(self, *, token: str, new_password: str) -> None:
        now = utc_now()
        record = await self.tokens.consume_active_for_update(
            token_hash=hash_token(token),
            purpose=OneTimeTokenPurpose.reset_password,
            now=now,
        )
        if record is None:
            raise InvalidOneTimeToken("Invalid or expired reset token")

        user = await self.users.get_by_id(record.user_id)
        if user is None:
            raise InvalidOneTimeToken("Invalid or expired reset token")

        record.consumed_at = now
        user.password_hash = hash_password(new_password)
        await SessionService(self.db).revoke_all_for_user(user)
        await self.db.commit()

    async def delete_account(
        self,
        *,
        user: User,
        current_password: str | None,
    ) -> None:
        if user.password_hash is not None:
            if current_password is None or not verify_password(
                user.password_hash,
                current_password,
            ):
                raise ReauthenticationRequired("Reauthentication required")

        user.status = UserStatus.deletion_pending
        await SessionService(self.db).revoke_all_for_user(user)
        await self.db.flush()
        await self.db.delete(user)
        await self.db.commit()

    async def _create_one_time_token(
        self,
        *,
        user: User,
        purpose: OneTimeTokenPurpose,
        lifetime: timedelta,
    ) -> str:
        now = utc_now()
        await self.tokens.invalidate_active(
            user_id=user.id,
            purpose=purpose,
            now=now,
        )
        plaintext = generate_opaque_token()
        self.db.add(
            OneTimeToken(
                id=uuid.uuid4(),
                user_id=user.id,
                purpose=purpose,
                token_hash=hash_token(plaintext),
                expires_at=now + lifetime,
            )
        )
        return plaintext
