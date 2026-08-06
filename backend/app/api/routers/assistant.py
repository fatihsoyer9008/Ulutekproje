import logging
from time import perf_counter

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_rate_limiter
from app.assistant_schemas import AssistantQueryRequest, AssistantQueryResponse
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
        return await AssistantQueryService(
            db,
            max_period_days=settings.assistant_max_period_days,
        ).query(
            user_id=user_id,
            payload=payload,
            model=model,
        )
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
