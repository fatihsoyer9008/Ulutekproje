from dataclasses import dataclass

from app.models.oauth_account import OAuthProvider


@dataclass(frozen=True)
class OAuthIdentity:
    provider: OAuthProvider
    subject: str
    email: str | None
    email_verified: bool
    display_name: str | None = None
    provider_refresh_token: str | None = None


class OAuthValidationError(ValueError):
    pass


class OAuthConfigurationError(RuntimeError):
    pass


class OAuthProviderError(RuntimeError):
    pass
