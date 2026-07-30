import base64
import hashlib
from datetime import UTC, datetime, timedelta

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.hazmat.primitives.serialization import (
    Encoding,
    NoEncryption,
    PrivateFormat,
)
from pydantic import SecretStr

from app.core.config import settings
from app.services.apple_oauth import AppleOAuthProvider
from app.services.google_oauth import GoogleOAuthVerifier
from app.services.oauth_types import OAuthValidationError


def _google_claims(**overrides):
    claims = {
        "iss": "https://accounts.google.com",
        "aud": "google-client",
        "sub": "google-subject",
        "exp": (datetime.now(UTC) + timedelta(minutes=5)).timestamp(),
        "nonce": "expected-nonce",
        "email": "verified@example.com",
        "email_verified": True,
    }
    claims.update(overrides)
    return claims


def test_google_client_ids_accepts_legacy_web_client_name(monkeypatch) -> None:
    monkeypatch.setattr(settings, "google_oauth_client_ids", "")
    monkeypatch.setattr(settings, "google_web_client_id", "legacy-web-client")

    assert settings.google_client_ids == ("legacy-web-client",)


@pytest.mark.parametrize(
    ("claims", "token", "message"),
    [
        (_google_claims(aud="wrong-client"), "token", "audience"),
        (_google_claims(iss="https://attacker.example"), "token", "issuer"),
        (
            _google_claims(
                exp=(datetime.now(UTC) - timedelta(minutes=1)).timestamp()
            ),
            "token",
            "expired",
        ),
        (None, "invalid-signature", "invalid"),
    ],
)
def test_google_rejects_signature_audience_issuer_and_expiry(
    monkeypatch,
    claims,
    token,
    message,
) -> None:
    monkeypatch.setattr(settings, "google_oauth_client_ids", "google-client")

    def fake_verify(*args, **kwargs):
        if claims is None:
            raise ValueError("bad signature")
        return claims

    monkeypatch.setattr(
        "app.services.google_oauth.google_id_token.verify_oauth2_token",
        fake_verify,
    )
    with pytest.raises(OAuthValidationError, match=f"(?i){message}"):
        GoogleOAuthVerifier().verify(id_token=token, nonce="expected-nonce")


def _b64(value: int) -> str:
    length = (value.bit_length() + 7) // 8
    return base64.urlsafe_b64encode(value.to_bytes(length, "big")).rstrip(
        b"="
    ).decode()


def _apple_test_material(monkeypatch):
    signing_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public = signing_key.public_key().public_numbers()
    jwk = {
        "kty": "RSA",
        "kid": "apple-test-kid",
        "use": "sig",
        "alg": "RS256",
        "n": _b64(public.n),
        "e": _b64(public.e),
    }
    client_key = ec.generate_private_key(ec.SECP256R1())
    client_pem = client_key.private_bytes(
        Encoding.PEM,
        PrivateFormat.PKCS8,
        NoEncryption(),
    ).decode()
    monkeypatch.setattr(settings, "apple_client_id", "com.example.app")
    monkeypatch.setattr(settings, "apple_team_id", "TEAM123")
    monkeypatch.setattr(settings, "apple_key_id", "KEY123")
    monkeypatch.setattr(settings, "apple_private_key", SecretStr(client_pem))
    return signing_key, jwk


def _apple_identity_token(signing_key, **overrides) -> str:
    nonce = hashlib.sha256(b"raw-apple-nonce").hexdigest()
    claims = {
        "iss": "https://appleid.apple.com",
        "aud": "com.example.app",
        "sub": "apple-subject",
        "iat": datetime.now(UTC),
        "exp": datetime.now(UTC) + timedelta(minutes=5),
        "nonce": nonce,
        "email": "apple@example.com",
        "email_verified": "true",
    }
    claims.update(overrides)
    return jwt.encode(
        claims,
        signing_key,
        algorithm="RS256",
        headers={"kid": "apple-test-kid"},
    )


@pytest.mark.asyncio
async def test_apple_mock_authentication_and_revoke(monkeypatch) -> None:
    signing_key, jwk = _apple_test_material(monkeypatch)
    revoked: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/auth/keys"):
            return httpx.Response(200, json={"keys": [jwk]})
        body = request.content.decode()
        if request.url.path.endswith("/auth/token"):
            assert "code=one-time-code" in body
            return httpx.Response(200, json={"refresh_token": "apple-refresh"})
        if request.url.path.endswith("/auth/revoke"):
            revoked.append(body)
            return httpx.Response(200)
        return httpx.Response(404)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        provider = AppleOAuthProvider(client)
        identity = await provider.authenticate(
            identity_token=_apple_identity_token(signing_key),
            authorization_code="one-time-code",
            nonce="raw-apple-nonce",
        )
        await provider.revoke_refresh_token(identity.provider_refresh_token or "")

    assert identity.email_verified is True
    assert identity.provider_refresh_token == "apple-refresh"
    assert len(revoked) == 1
    assert "token=apple-refresh" in revoked[0]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "claim_overrides",
    [
        {"aud": "attacker-client"},
        {"iss": "https://attacker.example"},
        {"exp": datetime.now(UTC) - timedelta(minutes=1)},
    ],
)
async def test_apple_mock_rejects_invalid_claims(
    monkeypatch,
    claim_overrides,
) -> None:
    signing_key, jwk = _apple_test_material(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"keys": [jwk]})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        provider = AppleOAuthProvider(client)
        with pytest.raises(OAuthValidationError):
            await provider.authenticate(
                identity_token=_apple_identity_token(
                    signing_key,
                    **claim_overrides,
                ),
                authorization_code="one-time-code",
                nonce="raw-apple-nonce",
            )


@pytest.mark.asyncio
async def test_apple_mock_rejects_invalid_signature(monkeypatch) -> None:
    _, jwk = _apple_test_material(monkeypatch)
    attacker_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"keys": [jwk]})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        provider = AppleOAuthProvider(client)
        with pytest.raises(OAuthValidationError):
            await provider.authenticate(
                identity_token=_apple_identity_token(attacker_key),
                authorization_code="one-time-code",
                nonce="raw-apple-nonce",
            )
