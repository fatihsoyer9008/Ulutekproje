import uuid

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db_session
from app.core.oauth_crypto import OAuthTokenCipher
from app.core.rate_limit import RateLimiter
from app.core.redis import get_redis
from app.core.security import AccessTokenError, decode_access_token
from app.models.refresh_session import RefreshSession
from app.models.user import User, UserStatus
from app.services.apple_oauth import AppleOAuthProvider
from app.services.email_service import EmailSender, create_email_sender
from app.services.google_oauth import GoogleOAuthVerifier
from app.services.session_service import SessionMetadata

bearer_scheme = HTTPBearer(auto_error=False)


async def get_email_sender() -> EmailSender:
    return create_email_sender()


async def get_google_oauth_verifier() -> GoogleOAuthVerifier:
    return GoogleOAuthVerifier()


async def get_apple_oauth_provider() -> AppleOAuthProvider:
    return AppleOAuthProvider()


async def get_oauth_token_cipher() -> OAuthTokenCipher:
    return OAuthTokenCipher()


async def get_rate_limiter(redis: Redis = Depends(get_redis)) -> RateLimiter:
    return RateLimiter(redis)


def request_ip(request: Request) -> str:
    if settings.trust_proxy_headers:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",", maxsplit=1)[0].strip()
    return request.client.host if request.client is not None else "unknown"


def session_metadata(
    request: Request,
    *,
    device_id: str | None,
    device_name: str | None,
) -> SessionMetadata:
    return SessionMetadata(
        ip_address=request_ip(request),
        user_agent=request.headers.get("user-agent"),
        device_id=device_id,
        device_name=device_name,
    )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db_session),
) -> User:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired access token.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None or credentials.scheme.casefold() != "bearer":
        raise unauthorized

    try:
        payload = decode_access_token(credentials.credentials)
        user_id = uuid.UUID(payload["sub"])
        session_id = uuid.UUID(payload["sid"])
    except (AccessTokenError, TypeError, ValueError):
        raise unauthorized from None

    user = await db.get(User, user_id)
    refresh_session = await db.get(RefreshSession, session_id)
    if (
        user is None
        or user.status is not UserStatus.active
        or user.auth_version != int(payload["av"])
        or refresh_session is None
        or refresh_session.user_id != user.id
        or refresh_session.revoked_at is not None
    ):
        raise unauthorized
    return user
