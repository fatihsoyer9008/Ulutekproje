import hashlib
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
import jwt

from app.core.config import settings
from app.models.oauth_account import OAuthProvider
from app.services.oauth_types import (
    OAuthConfigurationError,
    OAuthIdentity,
    OAuthProviderError,
    OAuthValidationError,
)


class AppleOAuthProvider:
    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def authenticate(
        self,
        *,
        identity_token: str,
        authorization_code: str,
        nonce: str,
    ) -> OAuthIdentity:
        self._require_configuration()
        claims = await self._verify_identity_token(identity_token, nonce=nonce)
        token_response = await self._exchange_authorization_code(
            authorization_code
        )
        refresh_token = token_response.get("refresh_token")
        if not isinstance(refresh_token, str) or not refresh_token:
            raise OAuthProviderError("Apple did not return a refresh token")
        email = claims.get("email")
        return OAuthIdentity(
            provider=OAuthProvider.apple,
            subject=claims["sub"],
            email=email if isinstance(email, str) else None,
            email_verified=_claim_is_true(claims.get("email_verified")),
            provider_refresh_token=refresh_token,
        )

    async def revoke_refresh_token(self, refresh_token: str) -> None:
        self._require_configuration()
        payload = {
            "client_id": settings.apple_client_id,
            "client_secret": self._create_client_secret(),
            "token": refresh_token,
            "token_type_hint": "refresh_token",
        }
        response = await self._post(settings.apple_revoke_url, data=payload)
        if response.status_code != 200:
            raise OAuthProviderError(
                f"Apple token revoke failed with status {response.status_code}"
            )

    async def _verify_identity_token(
        self,
        identity_token: str,
        *,
        nonce: str,
    ) -> dict[str, Any]:
        try:
            header = jwt.get_unverified_header(identity_token)
        except jwt.PyJWTError as exc:
            raise OAuthValidationError("Invalid Apple identity token header") from exc
        kid = header.get("kid")
        if not isinstance(kid, str):
            raise OAuthValidationError("Apple identity token key ID is missing")

        response = await self._get(settings.apple_jwks_url)
        if response.status_code != 200:
            raise OAuthProviderError("Apple signing keys could not be loaded")
        try:
            keys = response.json().get("keys", [])
            key_data = next(
                (key for key in keys if key.get("kid") == kid),
                None,
            )
        except (AttributeError, ValueError) as exc:
            raise OAuthProviderError("Apple signing keys are invalid") from exc
        if key_data is None:
            raise OAuthValidationError("Apple signing key is unknown")
        try:
            signing_key = jwt.PyJWK.from_dict(key_data).key
            claims = jwt.decode(
                identity_token,
                signing_key,
                algorithms=["RS256"],
                audience=settings.apple_client_id,
                issuer=settings.apple_issuer,
                options={
                    "require": ["iss", "aud", "sub", "iat", "exp", "nonce"]
                },
            )
        except jwt.ExpiredSignatureError as exc:
            raise OAuthValidationError("Expired Apple identity token") from exc
        except jwt.PyJWTError as exc:
            raise OAuthValidationError("Invalid Apple identity token") from exc

        expected_nonce = hashlib.sha256(nonce.encode("utf-8")).hexdigest()
        if claims.get("nonce") != expected_nonce:
            raise OAuthValidationError("Invalid Apple token nonce")
        return claims

    async def _exchange_authorization_code(
        self,
        authorization_code: str,
    ) -> dict[str, Any]:
        response = await self._post(
            settings.apple_token_url,
            data={
                "client_id": settings.apple_client_id,
                "client_secret": self._create_client_secret(),
                "code": authorization_code,
                "grant_type": "authorization_code",
            },
        )
        if response.status_code != 200:
            raise OAuthValidationError("Invalid or expired Apple authorization code")
        try:
            payload = response.json()
        except ValueError as exc:
            raise OAuthProviderError("Apple token response is invalid") from exc
        if "error" in payload:
            raise OAuthValidationError("Apple authorization code exchange failed")
        return payload

    def _create_client_secret(self) -> str:
        if settings.apple_private_key is None:
            raise OAuthConfigurationError("Apple private key is not configured")
        now = datetime.now(UTC)
        private_key = settings.apple_private_key.get_secret_value().replace(
            "\\n", "\n"
        )
        try:
            return jwt.encode(
                {
                    "iss": settings.apple_team_id,
                    "iat": now,
                    "exp": now + timedelta(minutes=5),
                    "aud": settings.apple_issuer,
                    "sub": settings.apple_client_id,
                },
                private_key,
                algorithm="ES256",
                headers={"kid": settings.apple_key_id},
            )
        except (ValueError, jwt.PyJWTError) as exc:
            raise OAuthConfigurationError("Apple private key is invalid") from exc

    def _require_configuration(self) -> None:
        if not all(
            (
                settings.apple_client_id,
                settings.apple_team_id,
                settings.apple_key_id,
                settings.apple_private_key,
            )
        ):
            raise OAuthConfigurationError("Apple OAuth is not configured")

    async def _get(self, url: str) -> httpx.Response:
        try:
            if self._client is not None:
                return await self._client.get(url)
            async with httpx.AsyncClient(timeout=10) as client:
                return await client.get(url)
        except httpx.HTTPError as exc:
            raise OAuthProviderError("Apple service request failed") from exc

    async def _post(self, url: str, *, data: dict[str, str]) -> httpx.Response:
        try:
            if self._client is not None:
                return await self._client.post(url, data=data)
            async with httpx.AsyncClient(timeout=10) as client:
                return await client.post(url, data=data)
        except httpx.HTTPError as exc:
            raise OAuthProviderError("Apple service request failed") from exc


def _claim_is_true(value: object) -> bool:
    return value is True or (isinstance(value, str) and value.casefold() == "true")
