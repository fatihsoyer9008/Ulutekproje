from fastapi.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.config import settings

_MULTIPART_OVERHEAD_BYTES = 64 * 1024
_RECEIPT_IMAGE_PATH = "/api/v1/receipts/parse-image"


class ReceiptImageRequestTooLarge(RuntimeError):
    pass


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

        maximum_request_bytes = (
            settings.receipt_image_max_bytes + _MULTIPART_OVERHEAD_BYTES
        )
        headers = {key.lower(): value for key, value in scope.get("headers", [])}
        content_length = headers.get(b"content-length")

        if content_length is not None:
            try:
                declared_length = int(content_length)
            except ValueError:
                await self._send_error(
                    scope,
                    receive,
                    send,
                    status_code=400,
                    detail="Geçersiz Content-Length başlığı.",
                )
                return

            if declared_length < 0:
                await self._send_error(
                    scope,
                    receive,
                    send,
                    status_code=400,
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
            status_code=413,
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
    ) -> None:
        response = JSONResponse(
            status_code=status_code,
            content={"detail": detail},
        )
        await response(scope, receive, send)
