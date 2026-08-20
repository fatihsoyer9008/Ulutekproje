import uuid
from collections.abc import AsyncIterator

import httpx
import pytest
import pytest_asyncio
from cryptography.fernet import Fernet
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.dependencies import (
    get_apple_oauth_provider,
    get_debt_summary_cache,
    get_email_sender,
    get_google_oauth_verifier,
    get_oauth_token_cipher,
    get_rate_limiter,
)
from app.core.database import Base, get_db_session
from app.core.oauth_crypto import OAuthTokenCipher
from app.core.rate_limit import NoOpRateLimiter
from app.main import app
from app.models.oauth_account import OAuthAccount, OAuthProvider
from app.models.user import User, UserStatus
from app.services.oauth_types import (
    OAuthIdentity,
    OAuthProviderError,
    OAuthValidationError,
)


class NoOpEmailSender:
    async def send_verification(self, *, email: str, token: str) -> None:
        pass

    async def send_password_reset(self, *, email: str, token: str) -> None:
        pass


class NoOpDebtSummaryCache:
    async def invalidate_best_effort(self, group_id: uuid.UUID) -> bool:
        del group_id
        return True


class FakeGoogleVerifier:
    def __init__(self) -> None:
        self.error: OAuthValidationError | None = None
        self.identity = OAuthIdentity(
            provider=OAuthProvider.google,
            subject="google-subject-1",
            email="oauth@example.com",
            email_verified=True,
            display_name="OAuth User",
        )

    def verify(self, *, id_token: str, nonce: str) -> OAuthIdentity:
        assert id_token == "g" * 32
        assert nonce == "n" * 16
        if self.error is not None:
            raise self.error
        return self.identity


class FakeAppleProvider:
    def __init__(self) -> None:
        self.identity = OAuthIdentity(
            provider=OAuthProvider.apple,
            subject="apple-subject-1",
            email="apple@example.com",
            email_verified=True,
            provider_refresh_token="apple-refresh-plaintext",
        )
        self.revoked_tokens: list[str] = []
        self.fail_revoke = False

    async def authenticate(
        self,
        *,
        identity_token: str,
        authorization_code: str,
        nonce: str,
    ) -> OAuthIdentity:
        assert identity_token == "i" * 32
        assert authorization_code == "auth-code"
        assert nonce == "n" * 16
        return self.identity

    async def revoke_refresh_token(self, refresh_token: str) -> None:
        if self.fail_revoke:
            raise OAuthProviderError("simulated Apple outage")
        self.revoked_tokens.append(refresh_token)


@pytest_asyncio.fixture
async def oauth_context():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    google = FakeGoogleVerifier()
    apple = FakeAppleProvider()
    cipher = OAuthTokenCipher(Fernet.generate_key())

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_email_sender] = lambda: NoOpEmailSender()
    app.dependency_overrides[get_rate_limiter] = lambda: NoOpRateLimiter()
    app.dependency_overrides[get_google_oauth_verifier] = lambda: google
    app.dependency_overrides[get_apple_oauth_provider] = lambda: apple
    app.dependency_overrides[get_oauth_token_cipher] = lambda: cipher
    app.dependency_overrides[get_debt_summary_cache] = NoOpDebtSummaryCache

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield client, session_factory, google, apple, cipher

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_google_endpoint_creates_and_reuses_provider_account(
    oauth_context,
) -> None:
    client, session_factory, _, _, _ = oauth_context
    payload = {"id_token": "g" * 32, "nonce": "n" * 16}

    first = await client.post("/api/v1/auth/google", json=payload)
    second = await client.post("/api/v1/auth/google", json=payload)

    assert first.status_code == second.status_code == 200
    assert first.json()["user"]["id"] == second.json()["user"]["id"]
    async with session_factory() as session:
        accounts = list(await session.scalars(select(OAuthAccount)))
        assert len(accounts) == 1
        assert accounts[0].provider is OAuthProvider.google


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("code", "message"),
    [
        ("google_token_expired", "Google identity token has expired"),
        (
            "google_token_audience_mismatch",
            "Google token audience does not match the server client ID",
        ),
        ("google_token_issuer_mismatch", "Google token issuer is invalid"),
    ],
)
async def test_google_endpoint_returns_actionable_validation_error(
    oauth_context,
    code: str,
    message: str,
) -> None:
    client, _, google, _, _ = oauth_context
    google.error = OAuthValidationError(message, code=code)

    response = await client.post(
        "/api/v1/auth/google",
        json={"id_token": "g" * 32, "nonce": "n" * 16},
    )

    assert response.status_code == 401
    assert response.json()["detail"] == {
        "code": code,
        "message": "Google girişi doğrulanamadı. Lütfen tekrar deneyin.",
    }


@pytest.mark.asyncio
async def test_oauth_never_silently_links_unverified_existing_email(
    oauth_context,
) -> None:
    client, _, google, _, _ = oauth_context
    register = await client.post(
        "/api/v1/auth/register",
        json={
            "email": google.identity.email,
            "password": "A-strong-existing-password-123",
        },
    )
    assert register.status_code == 202

    # The registered account never completed EconBuddy's own email verification,
    # so we can't be sure the Google sign-in and the password account belong
    # to the same person — an attacker could have squatted the email without
    # ever proving they control the inbox.
    response = await client.post(
        "/api/v1/auth/google",
        json={"id_token": "g" * 32, "nonce": "n" * 16},
    )
    assert response.status_code == 409
    assert response.json()["detail"] == {
        "code": "google_account_already_exists",
        "message": (
            "Bu e-posta adresiyle mevcut bir hesap var. Güvenlik için "
            "önce e-posta ve şifrenizle giriş yapın."
        ),
    }


@pytest.mark.asyncio
async def test_oauth_links_to_verified_existing_account_and_logs_in(
    oauth_context,
) -> None:
    client, session_factory, google, _, _ = oauth_context
    register = await client.post(
        "/api/v1/auth/register",
        json={
            "email": google.identity.email,
            "password": "A-strong-existing-password-123",
        },
    )
    assert register.status_code == 202

    async with session_factory() as session:
        user = await session.scalar(
            select(User).where(User.email == google.identity.email)
        )
        assert user is not None
        existing_user_id = user.id
        user.is_email_verified = True
        await session.commit()

    # Both sides now have independently proven mailbox ownership (EconBuddy's
    # own email verification, plus Google asserting email_verified=True), so
    # the Google sign-in should link straight into the existing account
    # instead of demanding a password login first.
    response = await client.post(
        "/api/v1/auth/google",
        json={"id_token": "g" * 32, "nonce": "n" * 16},
    )
    assert response.status_code == 200
    assert response.json()["user"]["id"] == str(existing_user_id)

    async with session_factory() as session:
        account = await session.scalar(
            select(OAuthAccount).where(
                OAuthAccount.provider_subject == google.identity.subject
            )
        )
        assert account is not None
        assert account.user_id == existing_user_id
        assert account.provider is OAuthProvider.google


@pytest.mark.asyncio
async def test_oauth_does_not_link_to_a_suspended_existing_account(
    oauth_context,
) -> None:
    client, session_factory, google, _, _ = oauth_context
    register = await client.post(
        "/api/v1/auth/register",
        json={
            "email": google.identity.email,
            "password": "A-strong-existing-password-123",
        },
    )
    assert register.status_code == 202

    async with session_factory() as session:
        user = await session.scalar(
            select(User).where(User.email == google.identity.email)
        )
        assert user is not None
        user.is_email_verified = True
        user.status = UserStatus.suspended
        await session.commit()

    response = await client.post(
        "/api/v1/auth/google",
        json={"id_token": "g" * 32, "nonce": "n" * 16},
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_oauth_rejects_unverified_provider_email(oauth_context) -> None:
    client, _, google, _, _ = oauth_context
    google.identity = OAuthIdentity(
        provider=OAuthProvider.google,
        subject="unverified-subject",
        email="unverified@example.com",
        email_verified=False,
    )
    response = await client.post(
        "/api/v1/auth/google",
        json={"id_token": "g" * 32, "nonce": "n" * 16},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_apple_refresh_token_is_encrypted_and_revoked_on_delete(
    oauth_context,
) -> None:
    client, session_factory, _, apple, cipher = oauth_context
    login = await client.post(
        "/api/v1/auth/apple",
        json={
            "identity_token": "i" * 32,
            "authorization_code": "auth-code",
            "nonce": "n" * 16,
        },
    )
    assert login.status_code == 200

    async with session_factory() as session:
        account = (
            await session.scalars(
                select(OAuthAccount).where(OAuthAccount.provider == OAuthProvider.apple)
            )
        ).one()
        encrypted = account.provider_refresh_token_encrypted
        assert encrypted is not None
        assert b"apple-refresh-plaintext" not in encrypted
        assert cipher.decrypt(encrypted) == "apple-refresh-plaintext"

    deleted = await client.request(
        "DELETE",
        "/api/v1/auth/me",
        headers={
            "Authorization": f"Bearer {login.json()['access_token']}",
        },
        json={},
    )
    assert deleted.status_code == 204
    assert apple.revoked_tokens == ["apple-refresh-plaintext"]


@pytest.mark.asyncio
async def test_apple_revoke_failure_disables_access_and_keeps_retry_state(
    oauth_context,
) -> None:
    client, session_factory, _, apple, _ = oauth_context
    login = await client.post(
        "/api/v1/auth/apple",
        json={
            "identity_token": "i" * 32,
            "authorization_code": "auth-code",
            "nonce": "n" * 16,
        },
    )
    apple.fail_revoke = True

    deleted = await client.request(
        "DELETE",
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
        json={},
    )
    assert deleted.status_code == 502

    async with session_factory() as session:
        user = (await session.scalars(select(User))).one()
        account = (await session.scalars(select(OAuthAccount))).one()
        assert user.status is UserStatus.deletion_pending
        assert account.provider_refresh_token_encrypted is not None

    me = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
    )
    assert me.status_code == 401
