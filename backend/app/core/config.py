from ipaddress import IPv4Network, IPv6Network, ip_network

from pydantic import AliasChoices, Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment-backed application configuration."""

    app_name: str = "Receipt Parser API"
    app_env: str = "development"
    api_host: str = "127.0.0.1"
    api_port: int = 8000

    database_url: str = (
        "postgresql+asyncpg://receipt_app:receipt_app@127.0.0.1:5432/receipt_app"
    )
    redis_url: SecretStr = SecretStr("redis://127.0.0.1:6379/0")
    debt_summary_cache_ttl_seconds: int = Field(default=300, ge=1, le=3600)

    jwt_secret: SecretStr = SecretStr(
        "development-only-change-this-secret-before-production"
    )
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "ulutekproje-api"
    jwt_audience: str = "ulutekproje-mobile"
    access_token_minutes: int = 15
    refresh_token_days: int = 30

    security_hmac_secret: SecretStr = SecretStr(
        "development-only-rate-limit-hmac-secret"
    )
    n8n_webhook_hmac_secret: SecretStr = SecretStr(
        "development-only-n8n-webhook-hmac-secret"
    )

    email_delivery_mode: str = "disabled"
    email_delivery_mode: str = "disabled"
    email_delivery_mode: str = "disabled"
    email_from: str = "noreply@example.invalid"
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = Field(default=587, ge=1, le=65535)
    smtp_user: str | None = Field(
        default=None,
        validation_alias=AliasChoices("SMTP_USER", "SMTP_USERNAME"),
    )
    smtp_password: SecretStr | None = None
    smtp_tls: bool = Field(
        default=True,
        validation_alias=AliasChoices("SMTP_TLS", "SMTP_START_TLS"),
    )
    smtp_timeout_seconds: float = Field(default=15.0, gt=0, le=60)
    email_action_base_url: str = "http://127.0.0.1:8000/api/v1/auth"
    app_deep_link_base_url: str = "fiskon://auth"

    rate_limit_enabled: bool = True
    group_invitation_user_hourly_limit: int = Field(default=20, ge=1, le=10_000)
    group_invitation_group_hourly_limit: int = Field(default=50, ge=1, le=100_000)
    group_invitation_email_daily_limit: int = Field(default=5, ge=1, le=10_000)
    trust_proxy_headers: bool = False
    trusted_client_ip_header: str = ""
    trusted_proxy_cidrs: str = ""
    cors_allowed_origins: str = ""
    receipt_image_upload_enabled: bool = False
    receipt_image_max_bytes: int = Field(
        default=10 * 1024 * 1024,
        ge=1,
        le=20 * 1024 * 1024,
    )
    receipt_image_max_pixels: int = Field(
        default=25_000_000,
        ge=1,
        le=50_000_000,
    )
    receipt_image_processing_concurrency: int = Field(
        default=2,
        ge=1,
        le=8,
    )
    receipt_ip_burst_limit: int = Field(default=10, ge=1, le=10_000)
    receipt_ip_daily_limit: int = Field(default=50, ge=1, le=1_000_000)
    receipt_installation_burst_limit: int = Field(
        default=5,
        ge=1,
        le=10_000,
    )
    receipt_installation_daily_limit: int = Field(
        default=25,
        ge=1,
        le=1_000_000,
    )

    assistant_enabled: bool = False
    assistant_model: str = "gemini-3.5-flash-lite"
    assistant_gemini_api_key: SecretStr | None = None
    assistant_consent_version: str = Field(
        default="2026-08-01",
        min_length=1,
        max_length=64,
    )
    assistant_request_timeout_ms: int = Field(
        default=25_000,
        ge=5_000,
        le=30_000,
    )
    assistant_provider_timeout_ms: int = Field(
        default=10_000,
        ge=1_000,
        le=30_000,
    )
    assistant_user_burst_limit: int = Field(default=6, ge=1, le=1_000)
    assistant_user_daily_limit: int = Field(default=100, ge=1, le=100_000)
    assistant_max_period_days: int = Field(default=3660, ge=1, le=36500)

    google_oauth_client_ids: str = ""
    # Backwards-compatible name used by the existing local environment.
    google_web_client_id: str = ""
    apple_client_id: str = ""
    apple_team_id: str = ""
    apple_key_id: str = ""
    apple_private_key: SecretStr | None = None
    apple_token_encryption_key: SecretStr | None = None
    apple_issuer: str = "https://appleid.apple.com"
    apple_jwks_url: str = "https://appleid.apple.com/auth/keys"
    apple_token_url: str = "https://appleid.apple.com/auth/token"
    apple_revoke_url: str = "https://appleid.apple.com/auth/revoke"

    gemini_api_key: SecretStr | None = None
    gemini_model: str = "gemini-3.5-flash-lite"
    use_dummy_parser: bool = True

    @field_validator("trusted_proxy_cidrs")
    @classmethod
    def validate_trusted_proxy_cidrs(cls, value: str) -> str:
        configured_cidrs = [item.strip() for item in value.split(",") if item.strip()]

        try:
            for cidr in configured_cidrs:
                ip_network(cidr, strict=False)
        except ValueError as exc:
            raise ValueError(
                "TRUSTED_PROXY_CIDRS must contain valid IPv4 or IPv6 networks"
            ) from exc

        return ",".join(configured_cidrs)

    @property
    def trusted_proxy_networks(
        self,
    ) -> tuple[IPv4Network | IPv6Network, ...]:
        return tuple(
            ip_network(cidr, strict=False)
            for cidr in self.trusted_proxy_cidrs.split(",")
            if cidr
        )

    @field_validator("cors_allowed_origins")
    @classmethod
    def validate_cors_allowed_origins(cls, value: str) -> str:
        origins = [item.strip() for item in value.split(",") if item.strip()]
        if "*" in origins:
            raise ValueError(
                "CORS_ALLOWED_ORIGINS must not contain a wildcard; "
                "list explicit origins instead"
            )
        return ",".join(origins)

    @property
    def cors_origins(self) -> tuple[str, ...]:
        return tuple(
            origin.strip()
            for origin in self.cors_allowed_origins.split(",")
            if origin.strip()
        )

    @field_validator("email_delivery_mode")
    @classmethod
    def validate_email_delivery_mode(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"disabled", "smtp"}:
            raise ValueError("EMAIL_DELIVERY_MODE must be disabled or smtp")
        return normalized

    @property
    def google_client_ids(self) -> tuple[str, ...]:
        configured = [
            client_id.strip()
            for client_id in self.google_oauth_client_ids.split(",")
            if client_id.strip()
        ]
        legacy = self.google_web_client_id.strip()
        if legacy:
            configured.append(legacy)
        return tuple(dict.fromkeys(configured))

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
