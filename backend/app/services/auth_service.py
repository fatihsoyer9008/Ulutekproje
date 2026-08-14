import uuid
from dataclasses import dataclass
from datetime import timedelta

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.oauth_crypto import OAuthTokenCipher
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
from app.models.oauth_account import OAuthProvider
from app.models.one_time_token import OneTimeToken, OneTimeTokenPurpose
from app.models.user import User, UserStatus
from app.repositories.groups import GroupRepository
from app.repositories.oauth_accounts import OAuthAccountRepository
from app.repositories.sessions import SessionRepository
from app.repositories.tokens import OneTimeTokenRepository
from app.repositories.users import UserRepository
from app.services.apple_oauth import AppleOAuthProvider
from app.services.email_service import EmailSender
from app.services.oauth_types import OAuthProviderError
from app.services.session_service import IssuedSession, SessionMetadata, SessionService


class InvalidCredentials(ValueError):
    pass


class InvalidOneTimeToken(ValueError):
    pass


class EmailNotVerified(ValueError):
    pass


class EmailAlreadyRegistered(ValueError):
    pass


class ReauthenticationRequired(ValueError):
    pass


class AccountDeletionFailed(RuntimeError):
    pass


@dataclass(frozen=True)
class PendingVerificationEmail:
    email: str
    token: str


class AuthService:
    def __init__(self, db: AsyncSession, email_sender: EmailSender) -> None:
        self.db = db
        self.email_sender = email_sender
        self.users = UserRepository(db)
        self.groups = GroupRepository(db)
        self.tokens = OneTimeTokenRepository(db)
        self.sessions = SessionRepository(db)
        self.oauth_accounts = OAuthAccountRepository(db)

    async def register(
        self,
        *,
        email: str,
        password: str,
        display_name: str | None,
    ) -> PendingVerificationEmail:
        normalized_email = normalize_email(email)
        existing = await self.users.get_by_email(normalized_email)
        if existing is not None:
            # Keep the expensive path similar without modifying the account.
            hash_password(password)
            raise EmailAlreadyRegistered("Email address is already registered")

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
            raise EmailAlreadyRegistered(
                "Email address is already registered"
            ) from None

        # SMTP delivery must not be part of the public registration response
        # path. The router dispatches this value after the response so SMTP
        # latency and failures cannot reveal whether the account existed.
        return PendingVerificationEmail(
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

        if not user.is_email_verified:
            raise EmailNotVerified("Email address is not verified")

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
        apple_provider: AppleOAuthProvider | None = None,
        token_cipher: OAuthTokenCipher | None = None,
    ) -> tuple[uuid.UUID, ...]:
        if user.password_hash is not None:
            if current_password is None or not verify_password(
                user.password_hash,
                current_password,
            ):
                raise ReauthenticationRequired("Reauthentication required")

        user.status = UserStatus.deletion_pending
        await SessionService(self.db).revoke_all_for_user(user)
        accounts = await self.oauth_accounts.list_for_user(user.id)
        for account in accounts:
            if account.provider is not OAuthProvider.apple:
                continue
            if (
                apple_provider is None
                or token_cipher is None
                or account.provider_refresh_token_encrypted is None
            ):
                await self.db.commit()
                raise AccountDeletionFailed(
                    "Apple account revocation is not available"
                )
            try:
                refresh_token = token_cipher.decrypt(
                    account.provider_refresh_token_encrypted
                )
                await apple_provider.revoke_refresh_token(refresh_token)
            except (OAuthProviderError, RuntimeError) as exc:
                # Keep deletion_pending and revoked app sessions. A later
                # deletion retry can safely attempt Apple revocation again.
                await self.db.commit()
                raise AccountDeletionFailed(
                    "Apple account revocation failed"
                ) from exc
        affected_group_ids = await self.groups.prepare_for_user_deletion(
            user_id=user.id,
            archived_at=utc_now(),
        )
        await self.db.flush()
        await self.db.delete(user)
        await self.db.commit()
        return tuple(affected_group_ids)

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
