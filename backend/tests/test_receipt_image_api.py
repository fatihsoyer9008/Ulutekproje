import logging
from io import BytesIO

import pytest
from fastapi import HTTPException, status
from fastapi.testclient import TestClient
from PIL import Image

from app.api.dependencies import get_rate_limiter
from app.api.routers.receipts import get_receipt_parser_service
from app.core.config import settings
from app.core.rate_limit import NoOpRateLimiter, RateLimitRule
from app.main import app
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import ReceiptParserError


def create_image_bytes(image_format: str) -> bytes:
    output = BytesIO()
    image = Image.new("RGB", (2, 2), color="white")
    image.save(output, format=image_format)
    image.close()
    return output.getvalue()


JPEG_BYTES = create_image_bytes("JPEG")
PNG_BYTES = create_image_bytes("PNG")


def successful_response() -> ReceiptParserResponse:
    return ReceiptParserResponse(
        normalized_ocr_text="MARKET\nTOPLAM 25,50 TL",
        merchant="MARKET",
        total_amount_minor=2550,
        currency="TRY",
        date="2026-08-04T00:00:00Z",
        category="Market",
        confidence_score=0.95,
        is_parse_successful=True,
        items=[],
    )


class RecordingImageParser:
    model_name = "image-stub"

    def __init__(self) -> None:
        self.calls: list[tuple[bytes, str]] = []

    async def parse(
        self,
        request: ReceiptParserRequest,
    ) -> ReceiptParserResponse:
        del request
        return successful_response()

    async def parse_image(
        self,
        *,
        image_bytes: bytes,
        mime_type: str,
    ) -> ReceiptParserResponse:
        self.calls.append((image_bytes, mime_type))
        return successful_response()


class FailingImageParser(RecordingImageParser):
    async def parse_image(
        self,
        *,
        image_bytes: bytes,
        mime_type: str,
    ) -> ReceiptParserResponse:
        del image_bytes, mime_type
        raise ReceiptParserError("provider failed") from RuntimeError(
            "secret provider detail"
        )


class BlockingLimiter:
    async def enforce(
        self,
        rule: RateLimitRule,
        *,
        identifier: str,
    ) -> None:
        del rule, identifier
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again later.",
            headers={"Retry-After": "30"},
        )


@pytest.fixture(autouse=True)
def reset_dependency_overrides(
    monkeypatch: pytest.MonkeyPatch,
):
    app.dependency_overrides.clear()
    app.dependency_overrides[get_rate_limiter] = lambda: NoOpRateLimiter()
    monkeypatch.setattr(settings, "receipt_image_upload_enabled", True)
    yield
    app.dependency_overrides.clear()


@pytest.mark.parametrize(
    ("filename", "mime_type", "contents", "expected_format"),
    [
        ("receipt.jpg", "image/jpeg", JPEG_BYTES, "JPEG"),
        ("receipt.png", "image/png", PNG_BYTES, "PNG"),
    ],
)
def test_parse_image_accepts_supported_images(
    filename: str,
    mime_type: str,
    contents: bytes,
    expected_format: str,
) -> None:
    parser = RecordingImageParser()
    app.dependency_overrides[get_receipt_parser_service] = lambda: parser

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/receipts/parse-image",
            files={"image": (filename, contents, mime_type)},
        )

    assert response.status_code == 200
    assert len(parser.calls) == 1

    normalized_bytes, normalized_mime = parser.calls[0]
    assert normalized_mime == mime_type

    with Image.open(BytesIO(normalized_bytes)) as normalized_image:
        assert normalized_image.format == expected_format
        normalized_image.verify()

    assert response.json()["total_amount_minor"] == 2550


@pytest.mark.parametrize(
    ("filename", "mime_type", "contents"),
    [
        ("receipt.exe", "image/jpeg", JPEG_BYTES),
        ("receipt.png", "image/jpeg", JPEG_BYTES),
        ("receipt.jpg", "image/png", PNG_BYTES),
        ("receipt.png", "image/png", JPEG_BYTES),
        ("receipt.jpg", "image/jpeg", b"not-an-image"),
        ("receipt.gif", "image/gif", b"GIF89a"),
        ("receipt.jpg", "image/jpeg", b"\xff\xd8\xffforged-content"),
        ("receipt.png", "image/png", b"\x89PNG\r\n\x1a\nforged-content"),
    ],
)
def test_parse_image_rejects_forged_or_unsupported_files(
    filename: str,
    mime_type: str,
    contents: bytes,
) -> None:
    parser = RecordingImageParser()
    app.dependency_overrides[get_receipt_parser_service] = lambda: parser

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/receipts/parse-image",
            files={"image": (filename, contents, mime_type)},
        )

    assert response.status_code == 415
    assert parser.calls == []


def test_parse_image_rejects_empty_file() -> None:
    parser = RecordingImageParser()
    app.dependency_overrides[get_receipt_parser_service] = lambda: parser

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/receipts/parse-image",
            files={"image": ("receipt.jpg", b"", "image/jpeg")},
        )

    assert response.status_code == 400
    assert parser.calls == []


def test_parse_image_rejects_oversized_file(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    parser = RecordingImageParser()
    monkeypatch.setattr(settings, "receipt_image_max_bytes", 4)
    app.dependency_overrides[get_receipt_parser_service] = lambda: parser

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/receipts/parse-image",
            files={"image": ("receipt.jpg", JPEG_BYTES, "image/jpeg")},
        )

    assert response.status_code == 413
    assert parser.calls == []


def test_parse_image_requires_image_field() -> None:
    parser = RecordingImageParser()
    app.dependency_overrides[get_receipt_parser_service] = lambda: parser

    with TestClient(app) as client:
        response = client.post("/api/v1/receipts/parse-image")

    assert response.status_code == 422
    assert parser.calls == []


def test_rate_limit_prevents_image_parser_call() -> None:
    parser = RecordingImageParser()
    app.dependency_overrides[get_rate_limiter] = lambda: BlockingLimiter()
    app.dependency_overrides[get_receipt_parser_service] = lambda: parser

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/receipts/parse-image",
            files={"image": ("receipt.jpg", JPEG_BYTES, "image/jpeg")},
        )

    assert response.status_code == 429
    assert response.headers["Retry-After"] == "30"
    assert parser.calls == []


def test_parse_image_maps_provider_error_to_bad_gateway(caplog) -> None:
    caplog.set_level(logging.WARNING, logger="app.receipts")
    app.dependency_overrides[get_receipt_parser_service] = FailingImageParser

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/receipts/parse-image",
            files={"image": ("receipt.jpg", JPEG_BYTES, "image/jpeg")},
        )

    assert response.status_code == 502
    assert response.json() == {
        "detail": ("Fiş görüntüsü yapay zekâ servisi tarafından ayrıştırılamadı")
    }

    messages = [record.getMessage() for record in caplog.records]
    assert any(
        "receipt_image_provider_failed" in message
        and "error_type=RuntimeError" in message
        for message in messages
    )
    assert all("secret provider detail" not in message for message in messages)


def test_parse_image_is_unavailable_when_feature_is_disabled(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    parser = RecordingImageParser()
    monkeypatch.setattr(settings, "receipt_image_upload_enabled", False)
    app.dependency_overrides[get_receipt_parser_service] = lambda: parser

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/receipts/parse-image",
            files={"image": ("receipt.jpg", JPEG_BYTES, "image/jpeg")},
        )

    assert response.status_code == 503
    assert parser.calls == []
