import asyncio
import logging
from datetime import UTC, datetime
from time import perf_counter

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_rate_limiter
from app.assistant_schemas import (
    AssistantConsentUpdateRequest,
    AssistantQueryRequest,
    AssistantQueryResponse,
    AssistantStatusResponse,
)
from app.core.assistant_rate_limits import enforce_assistant_rate_limits
from app.core.config import settings
from app.core.database import get_db_session
from app.core.rate_limit import RateLimiter
from app.models.user import User
from app.services.assistant_service import (
    AssistantModelService,
    AssistantProviderError,
    AssistantQueryService,
    GeminiAssistantModelService,
    InvalidAssistantPeriod,
)

router = APIRouter(prefix="/api/v1/assistant", tags=["assistant"])
logger = logging.getLogger("app.assistant")


def get_assistant_model_service() -> AssistantModelService:
    if not settings.assistant_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI assistant is not enabled.",
        )

    api_key = (
        settings.gemini_api_key.get_secret_value().strip()
        if settings.gemini_api_key is not None
        else ""
    )
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI assistant provider is not configured.",
        )

    return GeminiAssistantModelService(
        api_key=api_key,
        model=settings.assistant_model,
        timeout_ms=settings.assistant_provider_timeout_ms,
    )


def _has_current_assistant_consent(user: User) -> bool:
    return (
        user.assistant_consent_version == settings.assistant_consent_version
        and user.assistant_consent_granted_at is not None
        and user.assistant_consent_revoked_at is None
    )


def _assistant_status(user: User) -> AssistantStatusResponse:
    return AssistantStatusResponse(
        enabled=settings.assistant_enabled,
        required_consent_version=settings.assistant_consent_version,
        consent_granted=_has_current_assistant_consent(user),
        consent_granted_at=user.assistant_consent_granted_at,
        consent_revoked_at=user.assistant_consent_revoked_at,
    )


@router.get("/status", response_model=AssistantStatusResponse)
async def assistant_status(
    user: User = Depends(get_current_user),
) -> AssistantStatusResponse:
    return _assistant_status(user)


@router.put("/consent", response_model=AssistantStatusResponse)
async def update_assistant_consent(
    payload: AssistantConsentUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> AssistantStatusResponse:
    if (
        payload.accepted
        and payload.consent_version != settings.assistant_consent_version
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Assistant consent text has changed.",
        )

    now = datetime.now(UTC)
    if payload.accepted:
        user.assistant_consent_version = settings.assistant_consent_version
        user.assistant_consent_granted_at = now
        user.assistant_consent_revoked_at = None
    else:
        if user.assistant_consent_version is None:
            user.assistant_consent_version = settings.assistant_consent_version
        user.assistant_consent_revoked_at = now

    await db.commit()
    return _assistant_status(user)


@router.post("/query", response_model=AssistantQueryResponse)
async def query_assistant(
    payload: AssistantQueryRequest,
    request: Request,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
    limiter: RateLimiter = Depends(get_rate_limiter),
    model: AssistantModelService = Depends(get_assistant_model_service),
) -> AssistantQueryResponse:
    if not settings.assistant_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI assistant is not enabled.",
        )
    if not _has_current_assistant_consent(user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Current AI data processing consent is required.",
        )
    user_id = user.id
    await db.rollback()

    await enforce_assistant_rate_limits(
        user_id=str(user_id),
        limiter=limiter,
    )

    started_at = perf_counter()
    request_id = getattr(request.state, "request_id", "unknown")
    outcome = "success"

    try:
        async with asyncio.timeout(settings.assistant_request_timeout_ms / 1000):
            return await AssistantQueryService(
                db,
                max_period_days=settings.assistant_max_period_days,
            ).query(
                user_id=user_id,
                payload=payload,
                model=model,
            )
    except TimeoutError as exc:
        outcome = "timeout"
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="AI assistant request timed out.",
        ) from exc
    except InvalidAssistantPeriod as exc:
        outcome = "invalid_period"
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Requested financial period is not supported.",
        ) from exc
    except AssistantProviderError as exc:
        outcome = "provider_error"
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI assistant could not generate an answer.",
        ) from exc
    except Exception:
        outcome = "unexpected_error"
        raise
    finally:
        duration_ms = (perf_counter() - started_at) * 1000
        logger.info(
            "assistant_query_completed request_id=%s duration_ms=%.2f "
            "model=%s outcome=%s",
            request_id,
            duration_ms,
            model.model_name,
            outcome,
        )
