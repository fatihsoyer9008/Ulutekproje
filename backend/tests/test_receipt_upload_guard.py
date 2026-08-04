from collections import deque

import pytest
from starlette.types import Message, Scope

from app.core.config import settings
from app.core.receipt_upload_guard import ReceiptImageBodyLimitMiddleware


@pytest.mark.asyncio
async def test_chunked_image_request_is_stopped_at_body_limit(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "receipt_image_max_bytes", 4)

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

    async def downstream(scope, receive, send) -> None:
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

    middleware = ReceiptImageBodyLimitMiddleware(downstream)
    scope: Scope = {
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

    await middleware(scope, receive, send)

    response_start = next(
        message for message in sent if message["type"] == "http.response.start"
    )
    assert response_start["status"] == 413
