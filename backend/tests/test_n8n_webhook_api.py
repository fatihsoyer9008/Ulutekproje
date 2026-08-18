import hashlib
import hmac
import json
import time
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_rate_limiter
from app.core.config import settings
from app.core.database import Base, get_db_session
from app.core.rate_limit import NoOpRateLimiter
from app.main import app
from app.models.cloud_receipt import CloudReceipt, CloudReceiptStatus
from app.models.n8n_webhook_event import N8nWebhookEvent
from app.models.user import User, UserStatus

WEBHOOK_PATH = "/api/v1/integrations/n8n/events"


def _sign(*, timestamp: str, raw_body: bytes) -> str:
    signed_payload = f"{timestamp}.".encode() + raw_body
    digest = hmac.new(
        settings.n8n_webhook_hmac_secret.get_secret_value().encode("utf-8"),
        signed_payload,
        hashlib.sha256,
    ).hexdigest()
    return f"sha256={digest}"


def _headers(
    *,
    raw_body: bytes,
    idempotency_key: str,
    timestamp: str | None = None,
    signature: str | None = None,
) -> dict[str, str]:
    resolved_timestamp = timestamp or str(int(time.time()))
    resolved_signature = signature or _sign(
        timestamp=resolved_timestamp, raw_body=raw_body
    )
    return {
        "Idempotency-Key": idempotency_key,
        "X-Webhook-Timestamp": resolved_timestamp,
        "X-Webhook-Signature": resolved_signature,
        "Content-Type": "application/json",
    }


def _envelope_bytes(
    *,
    event_type: str = "group_expense.created",
    event_id: uuid.UUID | None = None,
    data: dict | None = None,
) -> bytes:
    envelope = {
        "event_type": event_type,
        "event_id": str(event_id or uuid.uuid4()),
        "occurred_at": datetime.now(UTC).isoformat(),
        "schema_version": 1,
        "data": data or {},
    }
    return json.dumps(envelope).encode("utf-8")


@pytest_asyncio.fixture
async def webhook_context():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_rate_limiter] = lambda: NoOpRateLimiter()

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        yield client, session_factory

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_valid_signature_is_accepted(webhook_context) -> None:
    client, _ = webhook_context
    body = _envelope_bytes()
    key = str(uuid.uuid4())

    response = await client.post(
        WEBHOOK_PATH, content=body, headers=_headers(raw_body=body, idempotency_key=key)
    )

    assert response.status_code == 202
    assert response.json()["status"] == "accepted"


@pytest.mark.asyncio
async def test_invalid_signature_is_rejected(webhook_context) -> None:
    client, _ = webhook_context
    body = _envelope_bytes()
    key = str(uuid.uuid4())
    headers = _headers(
        raw_body=body, idempotency_key=key, signature="sha256=" + "0" * 64
    )

    response = await client.post(WEBHOOK_PATH, content=body, headers=headers)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_signature"


@pytest.mark.asyncio
async def test_stale_timestamp_is_rejected(webhook_context) -> None:
    client, _ = webhook_context
    body = _envelope_bytes()
    key = str(uuid.uuid4())
    stale_timestamp = str(int(time.time()) - 600)
    headers = _headers(
        raw_body=body, idempotency_key=key, timestamp=stale_timestamp
    )

    response = await client.post(WEBHOOK_PATH, content=body, headers=headers)

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_timestamp"


@pytest.mark.asyncio
async def test_missing_idempotency_key_is_rejected(webhook_context) -> None:
    client, _ = webhook_context
    body = _envelope_bytes()
    headers = _headers(raw_body=body, idempotency_key="short")
    del headers["Idempotency-Key"]
    headers["X-Webhook-Timestamp"] = str(int(time.time()))
    headers["X-Webhook-Signature"] = _sign(
        timestamp=headers["X-Webhook-Timestamp"], raw_body=body
    )

    response = await client.post(WEBHOOK_PATH, content=body, headers=headers)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "invalid_idempotency_key"


@pytest.mark.asyncio
async def test_same_key_and_payload_replays_cached_result(webhook_context) -> None:
    client, session_factory = webhook_context
    body = _envelope_bytes()
    key = str(uuid.uuid4())
    headers = _headers(raw_body=body, idempotency_key=key)

    first = await client.post(WEBHOOK_PATH, content=body, headers=headers)
    second = await client.post(WEBHOOK_PATH, content=body, headers=headers)

    assert first.status_code == 202
    assert second.status_code == 202
    assert first.json() == second.json()
    assert second.headers["Idempotency-Replayed"] == "true"
    assert "Idempotency-Replayed" not in first.headers

    async with session_factory() as session:
        count = len((await session.scalars(select(N8nWebhookEvent))).all())
    assert count == 1


@pytest.mark.asyncio
async def test_same_key_different_payload_conflicts(webhook_context) -> None:
    client, _ = webhook_context
    key = str(uuid.uuid4())
    first_body = _envelope_bytes(data={"group_id": str(uuid.uuid4())})
    second_body = _envelope_bytes(data={"group_id": str(uuid.uuid4())})

    first = await client.post(
        WEBHOOK_PATH,
        content=first_body,
        headers=_headers(raw_body=first_body, idempotency_key=key),
    )
    second = await client.post(
        WEBHOOK_PATH,
        content=second_body,
        headers=_headers(raw_body=second_body, idempotency_key=key),
    )

    assert first.status_code == 202
    assert second.status_code == 409
    assert second.json()["detail"]["code"] == "idempotency_conflict"


@pytest.mark.asyncio
async def test_receipt_parsed_creates_a_receipt_for_the_matched_user(
    webhook_context,
) -> None:
    client, session_factory = webhook_context
    user_id = uuid.uuid4()

    async with session_factory() as session:
        session.add(User(id=user_id, email="webhook-import@example.com"))
        await session.commit()

    event_id = uuid.uuid4()
    body = _envelope_bytes(
        event_type="receipt.parsed",
        event_id=event_id,
        data={
            "email": "webhook-import@example.com",
            "merchant_name": "Örnek Market",
            "total_amount_in_minor": 12550,
            "currency": "try",
            "receipt_date": "2026-08-17T12:00:00Z",
            "category": "market",
        },
    )
    key = str(uuid.uuid4())

    response = await client.post(
        WEBHOOK_PATH, content=body, headers=_headers(raw_body=body, idempotency_key=key)
    )

    assert response.status_code == 201
    assert response.json() == {"event_id": str(event_id), "status": "created"}

    async with session_factory() as session:
        receipt = await session.scalar(
            select(CloudReceipt).where(CloudReceipt.user_id == user_id)
        )
    assert receipt is not None
    assert receipt.client_record_id == event_id
    assert receipt.merchant_name == "Örnek Market"
    assert receipt.total_amount_in_minor == 12550
    assert receipt.currency == "TRY"
    assert receipt.category == "market"
    assert receipt.is_parse_successful is True
    assert receipt.status == CloudReceiptStatus.draft


@pytest.mark.asyncio
async def test_receipt_parsed_without_merchant_or_amount_is_rejected(
    webhook_context,
) -> None:
    client, session_factory = webhook_context
    user_id = uuid.uuid4()

    async with session_factory() as session:
        session.add(User(id=user_id, email="webhook-no-amount@example.com"))
        await session.commit()

    body = _envelope_bytes(
        event_type="receipt.parsed",
        data={"email": "webhook-no-amount@example.com", "category": "Eğlence"},
    )
    key = str(uuid.uuid4())

    response = await client.post(
        WEBHOOK_PATH, content=body, headers=_headers(raw_body=body, idempotency_key=key)
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "invalid_payload"

    async with session_factory() as session:
        count = len(
            (
                await session.scalars(
                    select(CloudReceipt).where(CloudReceipt.user_id == user_id)
                )
            ).all()
        )
    assert count == 0


@pytest.mark.asyncio
async def test_receipt_parsed_replay_does_not_create_a_duplicate_receipt(
    webhook_context,
) -> None:
    client, session_factory = webhook_context
    user_id = uuid.uuid4()

    async with session_factory() as session:
        session.add(User(id=user_id, email="webhook-replay@example.com"))
        await session.commit()

    body = _envelope_bytes(
        event_type="receipt.parsed",
        data={
            "email": "webhook-replay@example.com",
            "merchant_name": "Test Market",
            "total_amount_in_minor": 100,
        },
    )
    key = str(uuid.uuid4())
    headers = _headers(raw_body=body, idempotency_key=key)

    first = await client.post(WEBHOOK_PATH, content=body, headers=headers)
    second = await client.post(WEBHOOK_PATH, content=body, headers=headers)

    assert first.status_code == 201
    assert second.status_code == 201
    assert second.headers["Idempotency-Replayed"] == "true"

    async with session_factory() as session:
        count = len(
            (
                await session.scalars(
                    select(CloudReceipt).where(CloudReceipt.user_id == user_id)
                )
            ).all()
        )
    assert count == 1


@pytest.mark.asyncio
async def test_receipt_parsed_for_unknown_email_is_rejected(webhook_context) -> None:
    client, _ = webhook_context
    body = _envelope_bytes(
        event_type="receipt.parsed",
        data={
            "email": "no-such-fiskon-user@example.com",
            "merchant_name": "Test Market",
            "total_amount_in_minor": 100,
        },
    )
    key = str(uuid.uuid4())

    response = await client.post(
        WEBHOOK_PATH, content=body, headers=_headers(raw_body=body, idempotency_key=key)
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "user_not_found"


@pytest.mark.asyncio
async def test_receipt_parsed_for_suspended_user_is_rejected(webhook_context) -> None:
    client, session_factory = webhook_context

    async with session_factory() as session:
        session.add(
            User(
                email="webhook-suspended@example.com",
                status=UserStatus.suspended,
            )
        )
        await session.commit()

    body = _envelope_bytes(
        event_type="receipt.parsed",
        data={
            "email": "webhook-suspended@example.com",
            "merchant_name": "Test Market",
            "total_amount_in_minor": 100,
        },
    )
    key = str(uuid.uuid4())

    response = await client.post(
        WEBHOOK_PATH, content=body, headers=_headers(raw_body=body, idempotency_key=key)
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "user_not_found"


@pytest.mark.asyncio
async def test_completion_log_omits_payload(webhook_context, caplog) -> None:
    client, _ = webhook_context
    secret_merchant_name = "GİZLİ-MARKET-ADI-SIZDIRILMAMALI"
    body = _envelope_bytes(data={"merchant_name": secret_merchant_name})
    key = str(uuid.uuid4())

    with caplog.at_level("INFO", logger="app.n8n_webhook"):
        response = await client.post(
            WEBHOOK_PATH,
            content=body,
            headers=_headers(raw_body=body, idempotency_key=key),
        )

    assert response.status_code == 202
    log_text = "\n".join(record.getMessage() for record in caplog.records)
    assert secret_merchant_name not in log_text
    assert "n8n_webhook_completed" in log_text
