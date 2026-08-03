from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response

from app.api.routers.auth import router as auth_router
from app.api.routers.receipts import router as receipt_router
from app.core.config import settings


def _validate_production_settings() -> None:
    if settings.app_env != "production":
        return

    if not settings.use_dummy_parser and not settings.rate_limit_enabled:
        raise RuntimeError(
            "RATE_LIMIT_ENABLED must be true when Gemini parsing is enabled"
        )

    weak_values = {
        "development-only-change-this-secret-before-production",
        "development-only-rate-limit-hmac-secret",
    }
    if settings.jwt_secret.get_secret_value() in weak_values:
        raise RuntimeError("JWT_SECRET must be replaced in production")
    if settings.security_hmac_secret.get_secret_value() in weak_values:
        raise RuntimeError("SECURITY_HMAC_SECRET must be replaced in production")
    if settings.email_delivery_mode != "smtp":
        raise RuntimeError("SMTP email delivery must be configured in production")
    smtp_password = (
        settings.smtp_password.get_secret_value().strip()
        if settings.smtp_password is not None
        else ""
    )
    if not all(
        (
            settings.email_from.strip(),
            settings.smtp_host.strip(),
            (settings.smtp_user or "").strip(),
            smtp_password,
        )
    ):
        raise RuntimeError(
            "EMAIL_FROM, SMTP_HOST, SMTP_USER and SMTP_PASSWORD are required "
            "in production"
        )
    if not settings.email_action_base_url.strip().lower().startswith("https://"):
        raise RuntimeError(
            "EMAIL_ACTION_BASE_URL must use HTTPS in production"
        )
    apple_values = (
        settings.apple_client_id,
        settings.apple_team_id,
        settings.apple_key_id,
        settings.apple_private_key,
        settings.apple_token_encryption_key,
    )
    if any(apple_values) and not all(apple_values):
        raise RuntimeError(
            "Apple OAuth requires client, team, key, private key and encryption key"
        )


@asynccontextmanager
async def lifespan(_: FastAPI):
    _validate_production_settings()
    yield


app = FastAPI(
    title=settings.app_name,
    version="0.2.0",
    lifespan=lifespan,
)
app.include_router(auth_router)
app.include_router(receipt_router)


@app.middleware("http")
async def prevent_auth_response_caching(
    request: Request,
    call_next,
) -> Response:
    response = await call_next(request)
    if request.url.path.startswith("/api/v1/auth/"):
        response.headers["Cache-Control"] = "no-store"
        response.headers["Pragma"] = "no-cache"
    return response


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    """Minimal endpoint used to verify the local server is running."""
    return {"status": "ok", "environment": settings.app_env}