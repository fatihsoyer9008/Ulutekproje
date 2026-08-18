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
from app.models.cloud_receipt import CloudReceipt
from app.models.n8n_webhook_event import N8nWebhookEvent
from app.n8n_webhook_schemas import N8nWebhookEnvelope, ReceiptParsedEventData

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


async def _match_receipt_event(
    *,
    data: dict,
    db: AsyncSession,
) -> tuple[int, dict]:
    try:
        payload = ReceiptParsedEventData.model_validate(data)
    except ValidationError as exc:
        raise _webhook_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "invalid_payload",
            "receipt.parsed verisi kullanıcı/fiş eşleştirmesi için geçersiz.",
        ) from exc

    receipt = await db.scalar(
        select(CloudReceipt).where(
            CloudReceipt.user_id == payload.user_id,
            CloudReceipt.client_record_id == payload.client_record_id,
        )
    )
    if receipt is None:
        raise _webhook_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "receipt_not_found",
            "Eşleşen kullanıcı/fiş kaydı bulunamadı.",
        )

    expected_installation_hash = privacy_hash(f"installation:{payload.installation_id}")
    if receipt.installation_id_hash != expected_installation_hash:
        raise _webhook_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "receipt_installation_mismatch",
            "Fiş, belirtilen cihazdan oluşturulmamış.",
        )

    return status.HTTP_200_OK, {"status": "matched"}


async def _process_event(
    *,
    envelope: N8nWebhookEnvelope,
    db: AsyncSession,
) -> tuple[int, dict]:
    if envelope.event_type == "receipt.parsed":
        status_code, body = await _match_receipt_event(data=envelope.data, db=db)
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
            status.HTTP_400_BAD_REQUEST, "invalid_timestamp", str(exc)
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
            status.HTTP_401_UNAUTHORIZED, "invalid_signature", str(exc)
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
