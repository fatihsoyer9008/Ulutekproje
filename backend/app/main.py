import logging
from contextlib import asynccontextmanager
from time import perf_counter

from fastapi import FastAPI, Request, Response, status
from fastapi.exception_handlers import (
    http_exception_handler,
)
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.routers.activity import router as activity_router
from app.api.routers.assistant import router as assistant_router
from app.api.routers.auth import router as auth_router
from app.api.routers.friends import router as friends_router
from app.api.routers.group_invitations import router as group_invitations_router
from app.api.routers.groups import router as groups_router
from app.api.routers.me import router as me_router
from app.api.routers.n8n_webhook import router as n8n_webhook_router
from app.api.routers.receipts import router as receipt_router
from app.api.routers.settlements import router as settlements_router
from app.api.routers.sync import router as sync_router
from app.core.config import settings
from app.core.observability import (
    PROCESS_TIME_HEADER,
    REQUEST_ID_HEADER,
    configure_personal_data_redaction,
    redact_personal_data,
    resolve_request_id,
)
from app.core.receipt_upload_guard import ReceiptImageBodyLimitMiddleware

request_logger = logging.getLogger("app.request")


def _validate_production_settings() -> None:
    if settings.app_env != "production":
        return

    if settings.receipt_image_upload_enabled:
        if settings.use_dummy_parser:
            raise RuntimeError(
                "Receipt image upload cannot use the dummy parser in production"
            )
        gemini_api_key = (
            settings.gemini_api_key.get_secret_value().strip()
            if settings.gemini_api_key is not None
            else ""
        )
        if not gemini_api_key:
            raise RuntimeError(
                "GEMINI_API_KEY is required when receipt image upload is enabled"
            )

    if settings.assistant_enabled:
        assistant_api_key = (
            settings.assistant_gemini_api_key.get_secret_value().strip()
            if settings.assistant_gemini_api_key is not None
            else ""
        )
        if not assistant_api_key:
            raise RuntimeError(
                "ASSISTANT_GEMINI_API_KEY is required when AI assistant is enabled"
            )
        if not settings.rate_limit_enabled:
            raise RuntimeError(
                "RATE_LIMIT_ENABLED must be true when AI assistant is enabled"
            )
    if not settings.use_dummy_parser and not settings.rate_limit_enabled:
        raise RuntimeError(
            "RATE_LIMIT_ENABLED must be true when Gemini parsing is enabled"
        )
    if (
        not settings.trust_proxy_headers
        or not settings.trusted_client_ip_header.strip()
        or not settings.trusted_proxy_networks
    ):
        raise RuntimeError(
            "TRUST_PROXY_HEADERS=true, TRUSTED_CLIENT_IP_HEADER and "
            "TRUSTED_PROXY_CIDRS are required in production"
        )

    weak_values = {
        "development-only-change-this-secret-before-production",
        "development-only-rate-limit-hmac-secret",
        "development-only-n8n-webhook-hmac-secret",
    }
    if settings.jwt_secret.get_secret_value() in weak_values:
        raise RuntimeError("JWT_SECRET must be replaced in production")
    if settings.security_hmac_secret.get_secret_value() in weak_values:
        raise RuntimeError("SECURITY_HMAC_SECRET must be replaced in production")

    n8n_webhook_hmac_secret = (
        settings.n8n_webhook_hmac_secret.get_secret_value().strip()
    )
    if not n8n_webhook_hmac_secret or n8n_webhook_hmac_secret in weak_values:
        raise RuntimeError(
            "N8N_WEBHOOK_HMAC_SECRET must be configured securely in production"
        )
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
        raise RuntimeError("EMAIL_ACTION_BASE_URL must use HTTPS in production")
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
    configure_personal_data_redaction()
    yield


app = FastAPI(
    title=settings.app_name,
    version="0.2.0",
    lifespan=lifespan,
)
app.add_middleware(ReceiptImageBodyLimitMiddleware)
if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_origins),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
app.include_router(activity_router)
app.include_router(assistant_router)
app.include_router(auth_router)
app.include_router(friends_router)
app.include_router(groups_router)
app.include_router(group_invitations_router)
app.include_router(me_router)
app.include_router(n8n_webhook_router)
app.include_router(receipt_router)
app.include_router(settlements_router)
app.include_router(sync_router)


@app.exception_handler(StarletteHTTPException)
async def api_http_exception_handler(
    request: Request,
    exc: StarletteHTTPException,
) -> Response:
    if (
        request.url.path == "/api/v1/groups"
        or request.url.path.startswith("/api/v1/groups/")
        or request.url.path.startswith("/api/v1/group-invitations/")
    ) and exc.status_code == status.HTTP_401_UNAUTHORIZED:
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "detail": {
                    "code": "unauthorized",
                    "message": "Geçerli bir oturum gereklidir.",
                }
            },
            headers=exc.headers,
        )
    return await http_exception_handler(request, exc)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> Response:
    if request.url.path == "/api/v1/groups" or request.url.path.startswith(
        "/api/v1/groups/"
    ):
        is_expense_request = request.method == "POST" and request.url.path.endswith(
            "/expenses"
        )
        is_settlement_request = request.method == "POST" and request.url.path.endswith(
            "/settlements"
        )

        if is_expense_request:
            message = (
                "Masraf isteği geçersiz; paylaşım türünü, tutarları ve "
                "katılımcıları kontrol edin."
            )
        elif is_settlement_request:
            message = (
                "Ödeme isteği geçersiz; kullanıcıları, tutarı, "
                "para birimini ve tarihi kontrol edin."
            )
        else:
            message = "Grup isteği geçersiz."

        return JSONResponse(
            status_code=(
                status.HTTP_422_UNPROCESSABLE_CONTENT
                if is_expense_request
                else status.HTTP_400_BAD_REQUEST
            ),
            content={
                "detail": {
                    "code": "invalid_request",
                    "message": message,
                }
            },
        )
    if request.url.path.startswith("/api/"):
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            content={
                "detail": {
                    "code": "invalid_request",
                    "message": (
                        "Gönderilen bilgiler geçersiz. Lütfen alanları kontrol edin."
                    ),
                }
            },
        )
    # API dışındaki bir rotada oluşması beklenmez; yine de teknik doğrulama
    # ayrıntılarını istemciye taşımayız.
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        content={"detail": "Gönderilen bilgiler geçersiz."},
    )


@app.middleware("http")
async def log_request(
    request: Request,
    call_next,
) -> Response:
    request_id = resolve_request_id(request.headers.get(REQUEST_ID_HEADER))
    request.state.request_id = request_id
    started_at = perf_counter()
    status_code = 500
    exception_logged = False

    try:
        response = await call_next(request)
        status_code = response.status_code
    except Exception:
        exception_logged = True
        duration_ms = (perf_counter() - started_at) * 1000
        request_logger.exception(
            "request_failed request_id=%s method=%s path=%s "
            "status_code=%s duration_ms=%.2f",
            request_id,
            request.method,
            redact_personal_data(request.url.path),
            status_code,
            duration_ms,
        )
        response = JSONResponse(
            status_code=status_code,
            content={
                "detail": "İşlem şu anda tamamlanamıyor. Lütfen daha sonra tekrar deneyin."
            },
        )

    duration_ms = (perf_counter() - started_at) * 1000
    response.headers[REQUEST_ID_HEADER] = request_id
    response.headers[PROCESS_TIME_HEADER] = f"{duration_ms:.2f}"
    if not exception_logged:
        request_logger.info(
            "request_completed request_id=%s method=%s path=%s "
            "status_code=%s duration_ms=%.2f",
            request_id,
            request.method,
            redact_personal_data(request.url.path),
            status_code,
            duration_ms,
        )
    return response


@app.middleware("http")
async def prevent_sensitive_response_caching(
    request: Request,
    call_next,
) -> Response:
    response = await call_next(request)
    if request.url.path.startswith(
        (
            "/api/v1/auth/",
            "/api/v1/assistant/",
            "/api/v1/group-invitations/",
            "/api/v1/groups",
        )
    ):
        response.headers["Cache-Control"] = "no-store"
        response.headers["Pragma"] = "no-cache"
    return response


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    """Minimal endpoint used to verify the local server is running."""
    return {"status": "ok", "environment": settings.app_env}
