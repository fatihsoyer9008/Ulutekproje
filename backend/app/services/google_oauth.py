from datetime import UTC, datetime
from typing import Any

from google.auth.exceptions import GoogleAuthError
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import id_token as google_id_token

from app.core.config import settings
from app.models.oauth_account import OAuthProvider
from app.services.oauth_types import (
    OAuthConfigurationError,
    OAuthIdentity,
    OAuthValidationError,
)

_GOOGLE_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}


class GoogleOAuthVerifier:
    def verify(self, *, id_token: str, nonce: str) -> OAuthIdentity:
        audiences = settings.google_client_ids
        if not audiences:
            raise OAuthConfigurationError("Google OAuth client IDs are not configured")
        try:
            claims: dict[str, Any] = google_id_token.verify_oauth2_token(
                id_token,
                GoogleRequest(),
                audience=list(audiences),
            )
        except (GoogleAuthError, ValueError) as exc:
            raise OAuthValidationError("Invalid Google identity token") from exc

        issuer = claims.get("iss")
        audience = claims.get("aud")
        expiration = claims.get("exp")
        if issuer not in _GOOGLE_ISSUERS:
            raise OAuthValidationError("Invalid Google token issuer")
        if not _audience_matches(audience, audiences):
            raise OAuthValidationError("Invalid Google token audience")
        if not isinstance(expiration, (int, float)) or expiration <= datetime.now(
            UTC
        ).timestamp():
            raise OAuthValidationError("Expired Google identity token")
        if claims.get("nonce") != nonce:
            raise OAuthValidationError("Invalid Google token nonce")

        subject = claims.get("sub")
        if not isinstance(subject, str) or not subject:
            raise OAuthValidationError("Google token subject is missing")
        email = claims.get("email")
        return OAuthIdentity(
            provider=OAuthProvider.google,
            subject=subject,
            email=email if isinstance(email, str) else None,
            email_verified=_claim_is_true(claims.get("email_verified")),
            display_name=(
                claims["name"] if isinstance(claims.get("name"), str) else None
            ),
        )


def _audience_matches(value: object, allowed: tuple[str, ...]) -> bool:
    if isinstance(value, str):
        return value in allowed
    if isinstance(value, list):
        return any(item in allowed for item in value)
    return False


def _claim_is_true(value: object) -> bool:
    return value is True or (isinstance(value, str) and value.casefold() == "true")
