from collections.abc import AsyncIterator

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_email_sender, get_rate_limiter
from app.core.database import Base, get_db_session
from app.core.rate_limit import NoOpRateLimiter
from app.main import app
from app.models.refresh_session import RefreshSession
from app.models.user import User


class CapturingEmailSender:
    def __init__(self) -> None:
        self.verification_tokens: list[tuple[str, str]] = []
        self.reset_tokens: list[tuple[str, str]] = []

    async def send_verification(self, *, email: str, token: str) -> None:
        self.verification_tokens.append((email, token))

    async def send_password_reset(self, *, email: str, token: str) -> None:
        self.reset_tokens.append((email, token))


@pytest_asyncio.fixture
async def auth_context():
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

    sender = CapturingEmailSender()

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_sender() -> CapturingEmailSender:
        return sender

    async def override_limiter() -> NoOpRateLimiter:
        return NoOpRateLimiter()

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_email_sender] = override_sender
    app.dependency_overrides[get_rate_limiter] = override_limiter

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport,
        base_url="http://test",
    ) as client:
        yield client, sender, session_factory

    app.dependency_overrides.clear()
    await engine.dispose()


async def _register_and_verify(
    client: httpx.AsyncClient,
    sender: CapturingEmailSender,
    *,
    email: str = "user@example.com",
    password: str = "A-strong-test-password-123",
) -> None:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "display_name": "Test User",
        },
    )
    assert response.status_code == 202
    verification_token = sender.verification_tokens[-1][1]
    response = await client.post(
        "/api/v1/auth/verify-email",
        json={"token": verification_token},
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_verification_email_link_requires_explicit_post(auth_context) -> None:
    client, sender, _ = auth_context
    password = "A-strong-test-password-123"
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "link@example.com",
            "password": password,
        },
    )
    assert response.status_code == 202
    verification_token = sender.verification_tokens[-1][1]

    response = await client.get(
        "/api/v1/auth/verify-email-link",
        params={"token": verification_token},
    )

    assert response.status_code == 200
    assert 'method="post"' in response.text
    assert response.headers["cache-control"] == "no-store"

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "link@example.com", "password": password},
    )
    assert response.status_code == 403

    response = await client.post(
        "/api/v1/auth/verify-email-link",
        params={"token": verification_token},
    )
    assert response.status_code == 200

    reused = await client.post(
        "/api/v1/auth/verify-email-link",
        params={"token": verification_token},
    )
    assert reused.status_code == 400

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "link@example.com", "password": password},
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_register_verify_login_and_me(auth_context) -> None:
    client, sender, session_factory = auth_context
    password = "A-strong-test-password-123"
    await _register_and_verify(client, sender, password=password)

    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "USER@example.com",
            "password": password,
            "device_id": "test-device",
        },
    )
    assert response.status_code == 200
    tokens = response.json()
    assert tokens["token_type"] == "bearer"
    assert tokens["user"]["is_email_verified"] is True

    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert response.status_code == 200
    assert response.json()["email"] == "user@example.com"
    assert response.headers["cache-control"] == "no-store"

    async with session_factory() as session:
        stored = (await session.scalars(select(RefreshSession))).one()
        assert stored.token_hash != tokens["refresh_token"]
        assert len(stored.token_hash) == 64


@pytest.mark.asyncio
async def test_unverified_password_account_cannot_login(auth_context) -> None:
    client, sender, _ = auth_context
    password = "A-strong-test-password-123"
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "pending@example.com",
            "password": password,
        },
    )
    assert response.status_code == 202
    assert sender.verification_tokens

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "pending@example.com", "password": password},
    )

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "email_not_verified"


@pytest.mark.asyncio
async def test_refresh_rotation_and_reuse_revokes_whole_family(
    auth_context,
) -> None:
    client, sender, _ = auth_context
    password = "A-strong-test-password-123"
    await _register_and_verify(client, sender, password=password)
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": password},
    )
    old_refresh = login.json()["refresh_token"]

    rotated = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh},
    )
    assert rotated.status_code == 200
    new_refresh = rotated.json()["refresh_token"]
    assert new_refresh != old_refresh

    reused = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh},
    )
    assert reused.status_code == 401
    assert "security violation" in reused.json()["detail"].lower()

    family_token = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": new_refresh},
    )
    assert family_token.status_code == 401


@pytest.mark.asyncio
async def test_password_reset_revokes_sessions(auth_context) -> None:
    client, sender, _ = auth_context
    old_password = "A-strong-test-password-123"
    new_password = "A-new-strong-password-456"
    await _register_and_verify(client, sender, password=old_password)
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": old_password},
    )
    old_refresh = login.json()["refresh_token"]

    response = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": "user@example.com"},
    )
    assert response.status_code == 202
    reset_token = sender.reset_tokens[-1][1]

    response = await client.get(
        "/api/v1/auth/reset-password-link",
        params={"token": reset_token},
    )
    assert response.status_code == 200
    assert "Yeni şifreni belirle" in response.text
    assert "/api/v1/auth/reset-password" in response.text

    unchanged_login = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": old_password},
    )
    assert unchanged_login.status_code == 200

    response = await client.post(
        "/api/v1/auth/reset-password",
        json={"token": reset_token, "new_password": new_password},
    )
    assert response.status_code == 200

    response = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh},
    )
    assert response.status_code == 401

    old_login = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": old_password},
    )
    assert old_login.status_code == 401
    new_login = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": new_password},
    )
    assert new_login.status_code == 200


@pytest.mark.asyncio
async def test_registration_responses_do_not_enumerate_accounts(auth_context) -> None:
    client, sender, _ = auth_context
    password = "A-strong-test-password-123"
    await _register_and_verify(client, sender, password=password)
    sent_before_duplicate = len(sender.verification_tokens)

    duplicate = await client.post(
        "/api/v1/auth/register",
        json={"email": "user@example.com", "password": password},
    )
    unknown = await client.post(
        "/api/v1/auth/register",
        json={"email": "new-user@example.com", "password": password},
    )

    assert duplicate.status_code == unknown.status_code == 202
    assert duplicate.json() == unknown.json() == {
        "message": "If the address is eligible, a verification email will be sent."
    }
    assert len(sender.verification_tokens) == sent_before_duplicate + 1


@pytest.mark.asyncio
async def test_login_responses_do_not_enumerate_accounts(auth_context) -> None:
    client, sender, _ = auth_context
    password = "A-strong-test-password-123"
    await _register_and_verify(client, sender, password=password)

    wrong_password = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "wrong"},
    )
    unknown_email = await client.post(
        "/api/v1/auth/login",
        json={"email": "missing@example.com", "password": "wrong"},
    )
    assert wrong_password.status_code == unknown_email.status_code == 401
    assert wrong_password.json() == unknown_email.json()


@pytest.mark.asyncio
async def test_logout_invalidates_access_session(auth_context) -> None:
    client, sender, _ = auth_context
    password = "A-strong-test-password-123"
    await _register_and_verify(client, sender, password=password)
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": password},
    )
    tokens = login.json()

    response = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert response.status_code == 204

    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_delete_account_requires_password_and_deletes_user(auth_context) -> None:
    client, sender, session_factory = auth_context
    password = "A-strong-test-password-123"
    await _register_and_verify(client, sender, password=password)
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": password},
    )
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    rejected = await client.request(
        "DELETE",
        "/api/v1/auth/me",
        headers=headers,
        json={"current_password": "wrong-password"},
    )
    assert rejected.status_code == 401

    deleted = await client.request(
        "DELETE",
        "/api/v1/auth/me",
        headers=headers,
        json={"current_password": password},
    )
    assert deleted.status_code == 204

    async with session_factory() as session:
        assert (await session.scalars(select(User))).one_or_none() is None
