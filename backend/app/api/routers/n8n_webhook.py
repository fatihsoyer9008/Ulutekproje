import hashlib
import json
import logging
from time import perf_counter
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_rate_limiter, request_ip
from app.core.database import get_db_session
from app.core.n8n_webhook_security import (
    N8nWebhookSignatureError,
    N8nWebhookTimestampError,
    verify_webhook_request,
)
from app.core.rate_limit import RateLimiter, RateLimitRule
from app.core.security import privacy_hash
from app.models.cloud_receipt import CloudReceipt, CloudReceiptStatus
from app.models.n8n_webhook_event import N8nWebhookEvent
from app.models.user import UserStatus
from app.n8n_webhook_schemas import N8nWebhookEnvelope, ReceiptParsedEventData
from app.repositories.users import UserRepository

router = APIRouter(prefix="/api/v1/integrations/n8n", tags=["n8n-webhook"])
logger = logging.getLogger("app.n8n_webhook")

N8N_WEBHOOK_IP = RateLimitRule("n8n-webhook-ip", 120, 60)

_MIN_IDEMPOTENCY_KEY_LENGTH = 8
_MAX_IDEMPOTENCY_KEY_LENGTH = 128


def _webhook_error(status_code: int, code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={"code": code, "message": message},
    )


def _log_webhook_outcome(
    *,
    request_id: str,
    event_type: str | None,
    status_code: int,
    duration_ms: float,
    replayed: bool = False,
) -> None:
    logger.info(
        "n8n_webhook_completed request_id=%s event_type=%s status_code=%s "
        "duration_ms=%.2f replayed=%s",
        request_id,
        event_type or "unknown",
        status_code,
        duration_ms,
        replayed,
    )


async def _create_receipt_from_email_event(
    *,
    envelope: N8nWebhookEnvelope,
    db: AsyncSession,
) -> tuple[int, dict]:
    try:
        payload = ReceiptParsedEventData.model_validate(envelope.data)
    except ValidationError as exc:
        raise _webhook_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "invalid_payload",
            "receipt.parsed verisi geçersiz.",
        ) from exc

    user = await UserRepository(db).get_by_email(payload.email)
    if user is None or user.status is not UserStatus.active:
        raise _webhook_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "user_not_found",
            "Bu e-posta adresine ait aktif bir kullanıcı bulunamadı.",
        )

    # `event_id` is already a globally unique, n8n-issued UUID, so reusing it
    # as `client_record_id` gives a second, DB-level duplicate guard on top
    # of the Idempotency-Key table (and needs no client-generated id, since
    # this receipt did not come from a device).
    receipt = CloudReceipt(
        user_id=user.id,
        client_record_id=envelope.event_id,
        installation_id_hash=privacy_hash(f"n8n-import:{user.id}"),
        merchant_name=payload.merchant_name,
        total_amount_in_minor=payload.total_amount_in_minor,
        currency=payload.currency,
        receipt_date=payload.receipt_date,
        category=payload.category,
        normalized_ocr_text=payload.normalized_ocr_text,
        is_parse_successful=True,
        status=CloudReceiptStatus.draft,
        client_created_at=envelope.occurred_at,
        client_updated_at=envelope.occurred_at,
    )
    db.add(receipt)
    await db.flush()

    return status.HTTP_201_CREATED, {"status": "created"}


async def _process_event(
    *,
    envelope: N8nWebhookEnvelope,
    db: AsyncSession,
) -> tuple[int, dict]:
    if envelope.event_type == "receipt.parsed":
        status_code, body = await _create_receipt_from_email_event(
            envelope=envelope, db=db
        )
        body["event_id"] = str(envelope.event_id)
        return status_code, body

    return status.HTTP_202_ACCEPTED, {
        "event_id": str(envelope.event_id),
        "status": "accepted",
    }


@router.post("/events")
async def receive_n8n_webhook_event(
    request: Request,
    idempotency_key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
    x_webhook_timestamp: Annotated[
        str | None, Header(alias="X-Webhook-Timestamp")
    ] = None,
    x_webhook_signature: Annotated[
        str | None, Header(alias="X-Webhook-Signature")
    ] = None,
    db: AsyncSession = Depends(get_db_session),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> JSONResponse:
    started_at = perf_counter()
    request_id = getattr(request.state, "request_id", "unknown")
    raw_body = await request.body()

    await limiter.enforce(N8N_WEBHOOK_IP, identifier=f"ip:{request_ip(request)}")

    try:
        verify_webhook_request(
            raw_body=raw_body,
            timestamp_header=x_webhook_timestamp,
            signature_header=x_webhook_signature,
        )
    except N8nWebhookTimestampError as exc:
        duration_ms = (perf_counter() - started_at) * 1000
        _log_webhook_outcome(
            request_id=request_id,
            event_type=None,
            status_code=status.HTTP_400_BAD_REQUEST,
            duration_ms=duration_ms,
        )
        raise _webhook_error(
            status.HTTP_400_BAD_REQUEST,
            "invalid_timestamp",
            "Webhook zaman bilgisi geçersiz.",
        ) from exc
    except N8nWebhookSignatureError as exc:
        duration_ms = (perf_counter() - started_at) * 1000
        _log_webhook_outcome(
            request_id=request_id,
            event_type=None,
            status_code=status.HTTP_401_UNAUTHORIZED,
            duration_ms=duration_ms,
        )
        raise _webhook_error(
            status.HTTP_401_UNAUTHORIZED,
            "invalid_signature",
            "Webhook imzası doğrulanamadı.",
        ) from exc

    if idempotency_key is None or not (
        _MIN_IDEMPOTENCY_KEY_LENGTH
        <= len(idempotency_key)
        <= _MAX_IDEMPOTENCY_KEY_LENGTH
    ):
        raise _webhook_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "invalid_idempotency_key",
            "Idempotency-Key 8-128 karakter arasında olmalıdır.",
        )

    try:
        envelope = N8nWebhookEnvelope.model_validate_json(raw_body)
    except ValidationError as exc:
        duration_ms = (perf_counter() - started_at) * 1000
        _log_webhook_outcome(
            request_id=request_id,
            event_type=None,
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            duration_ms=duration_ms,
        )
        raise _webhook_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "invalid_payload",
            "Webhook gövdesi n8n sözleşmesine uymuyor.",
        ) from exc

    request_hash = hashlib.sha256(raw_body).hexdigest()

    existing = await db.scalar(
        select(N8nWebhookEvent).where(
            N8nWebhookEvent.event_type == envelope.event_type,
            N8nWebhookEvent.idempotency_key == idempotency_key,
        )
    )
    if existing is not None:
        if existing.request_hash != request_hash:
            raise _webhook_error(
                status.HTTP_409_CONFLICT,
                "idempotency_conflict",
                "Idempotency-Key daha önce farklı bir payload ile kullanıldı.",
            )
        duration_ms = (perf_counter() - started_at) * 1000
        _log_webhook_outcome(
            request_id=request_id,
            event_type=envelope.event_type,
            status_code=existing.response_status,
            duration_ms=duration_ms,
            replayed=True,
        )
        return JSONResponse(
            status_code=existing.response_status,
            content=json.loads(existing.response_body),
            headers={"Idempotency-Replayed": "true"},
        )

    response_status, response_body = await _process_event(envelope=envelope, db=db)

    db.add(
        N8nWebhookEvent(
            event_type=envelope.event_type,
            idempotency_key=idempotency_key,
            event_id=envelope.event_id,
            request_hash=request_hash,
            response_status=response_status,
            response_body=json.dumps(response_body),
        )
    )
    await db.commit()

    duration_ms = (perf_counter() - started_at) * 1000
    _log_webhook_outcome(
        request_id=request_id,
        event_type=envelope.event_type,
        status_code=response_status,
        duration_ms=duration_ms,
    )
    return JSONResponse(status_code=response_status, content=response_body)
