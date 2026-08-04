import re

from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse
from redis.asyncio import Redis
from starlette.datastructures import Headers
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.api.dependencies import request_ip
from app.core.config import settings
from app.core.rate_limit import RateLimiter
from app.core.receipt_rate_limits import enforce_receipt_rate_limits

_MULTIPART_OVERHEAD_BYTES = 64 * 1024
_RECEIPT_IMAGE_PATH = "/api/v1/receipts/parse-image"
_INSTALLATION_ID_PATTERN = re.compile(r"^[A-Za-z0-9._:-]+$")


class ReceiptImageRequestTooLarge(RuntimeError):
    pass


def _installation_id_from_headers(headers: Headers) -> str | None:
    installation_id = headers.get("x-installation-id")
    if installation_id is None:
        return None
    if not 16 <= len(installation_id) <= 128:
        return None
    if _INSTALLATION_ID_PATTERN.fullmatch(installation_id) is None:
        return None
    return installation_id


async def enforce_receipt_image_access(scope: Scope) -> None:
    if not settings.receipt_image_upload_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Fiş görüntüsü ayrıştırma geçici olarak kullanılamıyor.",
        )

    headers = Headers(scope=scope)
    request = Request(scope)
    redis = Redis.from_url(
        settings.redis_url.get_secret_value(),
        encoding="utf-8",
        decode_responses=True,
    )

    try:
        await enforce_receipt_rate_limits(
            client_ip=request_ip(request),
            installation_id=_installation_id_from_headers(headers),
            limiter=RateLimiter(redis),
        )
    finally:
        await redis.aclose()


class ReceiptImageBodyLimitMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        if (
            scope["type"] != "http"
            or scope.get("method") != "POST"
            or scope.get("path") != _RECEIPT_IMAGE_PATH
        ):
            await self.app(scope, receive, send)
            return

        try:
            await enforce_receipt_image_access(scope)
        except HTTPException as exc:
            await self._send_error(
                scope,
                receive,
                send,
                status_code=exc.status_code,
                detail=str(exc.detail),
                headers=exc.headers,
            )
            return

        maximum_request_bytes = (
            settings.receipt_image_max_bytes + _MULTIPART_OVERHEAD_BYTES
        )
        headers = Headers(scope=scope)
        content_length = headers.get("content-length")

        if content_length is not None:
            try:
                declared_length = int(content_length)
            except ValueError:
                await self._send_error(
                    scope,
                    receive,
                    send,
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Geçersiz Content-Length başlığı.",
                )
                return

            if declared_length < 0:
                await self._send_error(
                    scope,
                    receive,
                    send,
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Geçersiz Content-Length başlığı.",
                )
                return

            if declared_length > maximum_request_bytes:
                await self._send_too_large(scope, receive, send)
                return

        received_bytes = 0

        async def limited_receive() -> Message:
            nonlocal received_bytes

            message = await receive()
            if message["type"] == "http.request":
                received_bytes += len(message.get("body", b""))
                if received_bytes > maximum_request_bytes:
                    raise ReceiptImageRequestTooLarge
            return message

        try:
            await self.app(scope, limited_receive, send)
        except ReceiptImageRequestTooLarge:
            await self._send_too_large(scope, receive, send)

    @staticmethod
    async def _send_too_large(
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        await ReceiptImageBodyLimitMiddleware._send_error(
            scope,
            receive,
            send,
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="Multipart istek izin verilen boyutu aşıyor.",
        )

    @staticmethod
    async def _send_error(
        scope: Scope,
        receive: Receive,
        send: Send,
        *,
        status_code: int,
        detail: str,
        headers: dict[str, str] | None = None,
    ) -> None:
        response = JSONResponse(
            status_code=status_code,
            content={"detail": detail},
            headers=headers,
        )
        await response(scope, receive, send)