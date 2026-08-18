import uuid

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.oauth_crypto import OAuthTokenCipher
from app.core.security import normalize_email, utc_now
from app.models.oauth_account import OAuthAccount, OAuthProvider
from app.models.user import User, UserStatus
from app.repositories.oauth_accounts import OAuthAccountRepository
from app.repositories.users import UserRepository
from app.services.oauth_types import OAuthIdentity, OAuthValidationError
from app.services.session_service import IssuedSession, SessionMetadata, SessionService


class AccountLinkingRequired(OAuthValidationError):
    pass


class OAuthLoginService:
    def __init__(
        self,
        db: AsyncSession,
        *,
        token_cipher: OAuthTokenCipher,
    ) -> None:
        self.db = db
        self.users = UserRepository(db)
        self.oauth_accounts = OAuthAccountRepository(db)
        self.token_cipher = token_cipher

    async def login_or_register(
        self,
        *,
        identity: OAuthIdentity,
        metadata: SessionMetadata,
    ) -> IssuedSession:
        account = await self.oauth_accounts.get_by_provider_subject(
            provider=identity.provider,
            subject=identity.subject,
        )
        if account is not None:
            user = await self.users.get_by_id(account.user_id)
            if user is None or user.status is not UserStatus.active:
                raise OAuthValidationError("OAuth account is not available")
            self._update_provider_account(account, identity)
            user.last_login_at = utc_now()
            issued = await SessionService(self.db).issue(
                user=user,
                metadata=metadata,
            )
            await self.db.commit()
            return issued

        if not identity.email or not identity.email_verified:
            raise OAuthValidationError(
                "A verified provider email address is required"
            )
        normalized_email = normalize_email(identity.email)
        existing_user = await self.users.get_by_email(normalized_email)
        if existing_user is not None:
            # Only auto-link when BOTH sides have independently proven mailbox
            # ownership: the provider says email_verified=True (checked above)
            # AND our own account already completed FişKon's email
            # verification. That second condition is what makes this safe —
            # an attacker who merely registers a password account with a
            # victim's email cannot complete FişKon's verification (it's sent
            # to the real inbox), so an unverified existing account can never
            # silently receive someone else's OAuth login. If either side
            # can't prove ownership, fall back to requiring an explicit
            # password login first.
            if (
                existing_user.status is not UserStatus.active
                or not existing_user.is_email_verified
            ):
                raise AccountLinkingRequired(
                    "Sign in to the existing account before linking this provider"
                )
            new_account = OAuthAccount(
                id=uuid.uuid4(),
                user_id=existing_user.id,
                provider=identity.provider,
                provider_subject=identity.subject,
                provider_email=normalized_email,
                provider_refresh_token_encrypted=self._encrypted_refresh_token(
                    identity
                ),
            )
            existing_user.last_login_at = utc_now()
            try:
                await self.oauth_accounts.add(new_account)
                issued = await SessionService(self.db).issue(
                    user=existing_user,
                    metadata=metadata,
                )
                await self.db.commit()
                return issued
            except IntegrityError as exc:
                await self.db.rollback()
                raise AccountLinkingRequired(
                    "OAuth account could not be linked safely"
                ) from exc

        user = User(
            id=uuid.uuid4(),
            email=normalized_email,
            password_hash=None,
            display_name=identity.display_name,
            is_email_verified=True,
            status=UserStatus.active,
            auth_version=1,
            last_login_at=utc_now(),
        )
        account = OAuthAccount(
            id=uuid.uuid4(),
            user_id=user.id,
            provider=identity.provider,
            provider_subject=identity.subject,
            provider_email=normalized_email,
            provider_refresh_token_encrypted=self._encrypted_refresh_token(
                identity
            ),
        )
        try:
            await self.users.add(user)
            await self.oauth_accounts.add(account)
            issued = await SessionService(self.db).issue(
                user=user,
                metadata=metadata,
            )
            await self.db.commit()
            return issued
        except IntegrityError as exc:
            await self.db.rollback()
            raise AccountLinkingRequired(
                "OAuth account could not be linked safely"
            ) from exc

    def _update_provider_account(
        self,
        account: OAuthAccount,
        identity: OAuthIdentity,
    ) -> None:
        if identity.email and identity.email_verified:
            account.provider_email = normalize_email(identity.email)
        encrypted = self._encrypted_refresh_token(identity)
        if encrypted is not None:
            account.provider_refresh_token_encrypted = encrypted

    def _encrypted_refresh_token(
        self,
        identity: OAuthIdentity,
    ) -> bytes | None:
        if identity.provider is not OAuthProvider.apple:
            return None
        if not identity.provider_refresh_token:
            raise OAuthValidationError("Apple refresh token is missing")
        return self.token_cipher.encrypt(identity.provider_refresh_token)
