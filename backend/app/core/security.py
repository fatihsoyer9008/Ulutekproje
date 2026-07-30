import hashlib
import hmac
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.core.config import settings


class AccessTokenError(ValueError):
    pass


password_hasher = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
)

# Login for an unknown address still performs an Argon2id verification so the
# response path does not trivially disclose whether an account exists.
DUMMY_PASSWORD_HASH = password_hasher.hash(
    "not-a-real-password-used-only-for-timing-equalization"
)


def utc_now() -> datetime:
    return datetime.now(UTC)


def normalize_email(email: str) -> str:
    return email.strip().casefold()


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password_hash: str, password: str) -> bool:
    try:
        return password_hasher.verify(password_hash, password)
    except (InvalidHashError, VerifyMismatchError):
        return False


def password_needs_rehash(password_hash: str) -> bool:
    try:
        return password_hasher.check_needs_rehash(password_hash)
    except InvalidHashError:
        return True


def generate_opaque_token() -> str:
    return secrets.token_urlsafe(48)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def privacy_hash(value: str) -> str:
    return hmac.new(
        settings.security_hmac_secret.get_secret_value().encode("utf-8"),
        value.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def create_access_token(
    *,
    user_id: uuid.UUID,
    session_id: uuid.UUID,
    auth_version: int,
) -> tuple[str, int]:
    now = utc_now()
    expires_at = now + timedelta(minutes=settings.access_token_minutes)
    payload: dict[str, Any] = {
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "sub": str(user_id),
        "sid": str(session_id),
        "av": auth_version,
        "jti": str(uuid.uuid4()),
        "iat": now,
        "exp": expires_at,
    }
    token = jwt.encode(
        payload,
        settings.jwt_secret.get_secret_value(),
        algorithm=settings.jwt_algorithm,
    )
    return token, int((expires_at - now).total_seconds())


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret.get_secret_value(),
            algorithms=[settings.jwt_algorithm],
            audience=settings.jwt_audience,
            issuer=settings.jwt_issuer,
            options={
                "require": ["iss", "aud", "sub", "sid", "av", "jti", "iat", "exp"]
            },
        )
    except jwt.PyJWTError as exc:
        raise AccessTokenError("Invalid access token") from exc

    try:
        uuid.UUID(payload["sub"])
        uuid.UUID(payload["sid"])
        int(payload["av"])
    except (KeyError, TypeError, ValueError) as exc:
        raise AccessTokenError("Invalid access token claims") from exc
    return payload
