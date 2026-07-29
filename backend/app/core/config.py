from pydantic import SecretStr, field_validator
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

    email_delivery_mode: str = "disabled"
    email_from: str = "noreply@example.invalid"
    smtp_host: str = "127.0.0.1"
    smtp_port: int = 1025
    smtp_username: str | None = None
    smtp_password: SecretStr | None = None
    smtp_start_tls: bool = False
    app_deep_link_base_url: str = "fiskon://auth"

    rate_limit_enabled: bool = True
    trust_proxy_headers: bool = False

    gemini_api_key: SecretStr | None = None
    gemini_model: str = "gemini-3.5-flash-lite"
    use_dummy_parser: bool = True

    @field_validator("email_delivery_mode")
    @classmethod
    def validate_email_delivery_mode(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"disabled", "smtp"}:
            raise ValueError("EMAIL_DELIVERY_MODE must be disabled or smtp")
        return normalized

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()

