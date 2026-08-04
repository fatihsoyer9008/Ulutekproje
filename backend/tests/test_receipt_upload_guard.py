from collections import deque

import pytest
from fastapi import HTTPException, status
from starlette.types import Message, Scope

import app.core.receipt_upload_guard as upload_guard
from app.core.config import settings
from app.core.receipt_upload_guard import ReceiptImageBodyLimitMiddleware


def image_scope() -> Scope:
    return {
        "type": "http",
        "asgi": {"version": "3.0", "spec_version": "2.3"},
        "http_version": "1.1",
        "method": "POST",
        "scheme": "http",
        "path": "/api/v1/receipts/parse-image",
        "raw_path": b"/api/v1/receipts/parse-image",
        "query_string": b"",
        "root_path": "",
        "headers": [],
        "client": ("127.0.0.1", 12345),
        "server": ("127.0.0.1", 8000),
        "state": {},
    }


async def downstream_response(scope, receive, send) -> None:
    del scope
    while True:
        message = await receive()
        if not message.get("more_body", False):
            break

    await send(
        {
            "type": "http.response.start",
            "status": 204,
            "headers": [],
        }
    )
    await send(
        {
            "type": "http.response.body",
            "body": b"",
        }
    )


@pytest.mark.asyncio
async def test_feature_flag_rejects_before_reading_body(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "receipt_image_upload_enabled", False)
    receive_calls = 0
    sent: list[Message] = []

    async def receive() -> Message:
        nonlocal receive_calls
        receive_calls += 1
        return {
            "type": "http.request",
            "body": b"unread-body",
            "more_body": False,
        }

    async def send(message: Message) -> None:
        sent.append(message)

    middleware = ReceiptImageBodyLimitMiddleware(downstream_response)
    await middleware(image_scope(), receive, send)

    response_start = next(
        message for message in sent if message["type"] == "http.response.start"
    )
    assert response_start["status"] == 503
    assert receive_calls == 0


@pytest.mark.asyncio
async def test_rate_limit_rejects_before_reading_body(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "receipt_image_upload_enabled", True)
    receive_calls = 0
    sent: list[Message] = []

    async def reject_access(scope: Scope) -> None:
        del scope
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again later.",
            headers={"Retry-After": "30"},
        )

    async def receive() -> Message:
        nonlocal receive_calls
        receive_calls += 1
        return {
            "type": "http.request",
            "body": b"unread-body",
            "more_body": False,
        }

    async def send(message: Message) -> None:
        sent.append(message)

    monkeypatch.setattr(
        upload_guard,
        "enforce_receipt_image_access",
        reject_access,
    )

    middleware = ReceiptImageBodyLimitMiddleware(downstream_response)
    await middleware(image_scope(), receive, send)

    response_start = next(
        message for message in sent if message["type"] == "http.response.start"
    )
    headers = dict(response_start["headers"])

    assert response_start["status"] == 429
    assert headers[b"retry-after"] == b"30"
    assert receive_calls == 0


@pytest.mark.asyncio
async def test_chunked_image_request_is_stopped_at_body_limit(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "receipt_image_upload_enabled", True)
    monkeypatch.setattr(settings, "receipt_image_max_bytes", 4)

    async def allow_access(scope: Scope) -> None:
        del scope

    monkeypatch.setattr(
        upload_guard,
        "enforce_receipt_image_access",
        allow_access,
    )

    incoming: deque[Message] = deque(
        [
            {
                "type": "http.request",
                "body": b"A" * 32_000,
                "more_body": True,
            },
            {
                "type": "http.request",
                "body": b"B" * 32_000,
                "more_body": True,
            },
            {
                "type": "http.request",
                "body": b"C" * 2_000,
                "more_body": False,
            },
        ]
    )
    sent: list[Message] = []

    async def receive() -> Message:
        return incoming.popleft()

    async def send(message: Message) -> None:
        sent.append(message)

    middleware = ReceiptImageBodyLimitMiddleware(downstream_response)
    await middleware(image_scope(), receive, send)

    response_start = next(
        message for message in sent if message["type"] == "http.response.start"
    )
    assert response_start["status"] == 413
