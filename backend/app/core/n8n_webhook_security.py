import hashlib
import hmac
from datetime import UTC, datetime

from app.core.config import settings

WEBHOOK_TIMESTAMP_SKEW_SECONDS = 300
_SIGNATURE_PREFIX = "sha256="


class N8nWebhookTimestampError(ValueError):
    pass


class N8nWebhookSignatureError(ValueError):
    pass


def _parse_timestamp(raw_timestamp: str) -> datetime:
    try:
        seconds = int(raw_timestamp)
    except (TypeError, ValueError):
        raise N8nWebhookTimestampError(
            "X-Webhook-Timestamp geçerli bir Unix zaman damgası değil."
        ) from None
    try:
        return datetime.fromtimestamp(seconds, tz=UTC)
    except (OverflowError, OSError, ValueError):
        raise N8nWebhookTimestampError(
            "X-Webhook-Timestamp geçerli bir Unix zaman damgası değil."
        ) from None


def verify_webhook_request(
    *,
    raw_body: bytes,
    timestamp_header: str | None,
    signature_header: str | None,
) -> None:
    if not timestamp_header:
        raise N8nWebhookTimestampError("X-Webhook-Timestamp eksik.")

    timestamp = _parse_timestamp(timestamp_header)
    skew_seconds = abs((datetime.now(UTC) - timestamp).total_seconds())
    if skew_seconds > WEBHOOK_TIMESTAMP_SKEW_SECONDS:
        raise N8nWebhookTimestampError("X-Webhook-Timestamp süresi geçmiş.")

    if not signature_header or not signature_header.startswith(_SIGNATURE_PREFIX):
        raise N8nWebhookSignatureError("X-Webhook-Signature eksik veya geçersiz.")

    provided_digest = signature_header[len(_SIGNATURE_PREFIX) :].strip()
    signed_payload = f"{timestamp_header}.".encode() + raw_body
    expected_digest = hmac.new(
        settings.n8n_webhook_hmac_secret.get_secret_value().encode("utf-8"),
        signed_payload,
        hashlib.sha256,
    ).hexdigest()

    if not hmac.compare_digest(provided_digest, expected_digest):
        raise N8nWebhookSignatureError("X-Webhook-Signature eşleşmiyor.")
