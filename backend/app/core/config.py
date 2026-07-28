from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Local settings loaded from the backend .env file."""

    app_name: str = "Receipt Parser API"
    app_env: str = "development"
    api_host: str = "127.0.0.1"
    api_port: int = 8000
    gemini_api_key: SecretStr | None = None
    gemini_model: str = "gemini-3.5-flash-lite"
    use_dummy_parser: bool = True

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()

