from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from pydantic import ValidationError

from app.constants.ai_prompts import (
    RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION,
    RECEIPT_IMAGE_EXTRACTION_SYSTEM_INSTRUCTION,
)
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import GeminiReceiptParserService, ReceiptParserError


def create_mock_gemini_client(
    *,
    parsed: dict[str, object] | None = None,
    text: str | None = None,
) -> MagicMock:
    """Create a provider mock without making a real Gemini API request."""
    client = MagicMock()
    async_client = MagicMock()
    async_client.aclose = AsyncMock()
    async_client.models.generate_content = AsyncMock()

    response = MagicMock()
    response.parsed = parsed
    response.text = text
    async_client.models.generate_content.return_value = response
    client.aio = async_client
    return client


def successful_payload() -> dict[str, object]:
    return {
        "normalized_ocr_text": (
            "Örnek Süpermarket\nTarih: 2026-07-28\nToplam: 25,50 TL"
        ),
        "merchant": "Örnek Süpermarket",
        "date": "2026-07-28T00:00:00",
        "total_amount_minor": 2550,
        "currency": "TRY",
        "category": "Market",
        "is_parse_successful": True,
        "confidence_score": 0.95,
        "items": [],
    }


def test_receipt_prompt_is_centralized_and_sent_as_system_instruction() -> None:
    config = GeminiReceiptParserService._generation_config()

    assert config.system_instruction == RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION
    assert config.response_schema is ReceiptParserResponse
    assert "normalized_ocr_text" in RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION
    assert "HALÜSİNASYON YASAKTIR" in RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION
    assert "kuruş" in RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION
    assert "null" in RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION
    assert "0.30" in RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION


@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_successful_ocr_returns_complete_receipt(mock_client_class) -> None:
    """A clear receipt returns corrected OCR and complete data in minor units."""
    mock_client = create_mock_gemini_client(parsed=successful_payload())
    mock_client_class.return_value = mock_client
    ocr_text = "ÖRNEK SÜPERMARKET\n28.07.2026\nTOPLAM 25,50 TL"

    result = await GeminiReceiptParserService(
        api_key="test-key",
        model="test-model",
    ).parse(ReceiptParserRequest(ocr_text=ocr_text))

    assert result.normalized_ocr_text.startswith("Örnek Süpermarket")
    assert result.merchant == "Örnek Süpermarket"
    assert result.date == datetime(2026, 7, 28)
    assert result.total_amount_minor == 2550
    assert result.is_parse_successful is True
    assert result.confidence_score == pytest.approx(0.95)
    call = mock_client.aio.models.generate_content.await_args
    assert call.kwargs["contents"] == ocr_text
    assert (
        call.kwargs["config"].system_instruction
        == RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION
    )
    mock_client.aio.aclose.assert_awaited_once()


@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_successful_image_uses_inline_bytes_and_image_prompt(
    mock_client_class,
) -> None:
    mock_client = create_mock_gemini_client(parsed=successful_payload())
    mock_client_class.return_value = mock_client
    image_bytes = b"\xff\xd8\xff\xe0receipt-image"

    result = await GeminiReceiptParserService(
        api_key="test-key",
        model="test-model",
    ).parse_image(
        image_bytes=image_bytes,
        mime_type="image/jpeg",
    )

    assert result.total_amount_minor == 2550

    call = mock_client.aio.models.generate_content.await_args
    image_part = call.kwargs["contents"][0]

    assert image_part.inline_data is not None
    assert image_part.inline_data.data == image_bytes
    assert image_part.inline_data.mime_type == "image/jpeg"
    assert (
        call.kwargs["config"].system_instruction
        == RECEIPT_IMAGE_EXTRACTION_SYSTEM_INSTRUCTION
    )
    mock_client.aio.aclose.assert_awaited_once()


@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_incomplete_ocr_keeps_missing_fields_editable(mock_client_class) -> None:
    """A torn receipt remains usable and exposes unreadable fields as null."""
    payload = successful_payload()
    payload.update(
        date=None,
        is_parse_successful=False,
        confidence_score=0.62,
    )
    mock_client_class.return_value = create_mock_gemini_client(parsed=payload)

    result = await GeminiReceiptParserService(
        api_key="test-key",
        model="test-model",
    ).parse(
        ReceiptParserRequest(
            ocr_text="ÖRNEK SÜPERMARKET\nTARİH: [SİLİNMİŞ]\nTOPLAM 25,50 TL",
        ),
    )

    assert result.merchant == "Örnek Süpermarket"
    assert result.date is None
    assert result.total_amount_minor == 2550
    assert result.is_parse_successful is False
    assert result.confidence_score < 0.70


@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_broken_ocr_returns_low_confidence_without_hallucinating(
    mock_client_class,
) -> None:
    """Non-receipt input produces no invented financial data and does not crash."""
    mock_client_class.return_value = create_mock_gemini_client(
        parsed={
            "normalized_ocr_text": "KEDİ FOTOĞRAFI OCR: xqz ### ???",
            "merchant": None,
            "date": None,
            "total_amount_minor": None,
            "currency": "TRY",
            "category": None,
            "is_parse_successful": False,
            "confidence_score": 0.05,
            "items": [],
        },
    )

    result = await GeminiReceiptParserService(
        api_key="test-key",
        model="test-model",
    ).parse(ReceiptParserRequest(ocr_text="KEDİ FOTOĞRAFI OCR: xqz ### ???"))

    assert result.merchant is None
    assert result.date is None
    assert result.total_amount_minor is None
    assert result.category is None
    assert result.items == []
    assert result.is_parse_successful is False
    assert result.confidence_score <= 0.30


@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_invalid_provider_response_becomes_parser_error(
    mock_client_class,
) -> None:
    mock_client_class.return_value = create_mock_gemini_client(
        text="this is not valid JSON",
    )

    with pytest.raises(ReceiptParserError, match="ayrıştıramadı"):
        await GeminiReceiptParserService(
            api_key="test-key",
            model="test-model",
        ).parse(ReceiptParserRequest(ocr_text="bulanık metin"))


@pytest.mark.parametrize("missing_field", ["merchant", "date", "total_amount_minor"])
def test_successful_response_rejects_missing_required_field(missing_field) -> None:
    payload = successful_payload()
    payload[missing_field] = None

    with pytest.raises(ValidationError):
        ReceiptParserResponse.model_validate(payload)


@pytest.mark.parametrize("score", [-0.01, 1.01])
def test_confidence_score_must_be_between_zero_and_one(score) -> None:
    with pytest.raises(ValidationError):
        ReceiptParserResponse(
            normalized_ocr_text="Bozuk OCR",
            merchant=None,
            total_amount_minor=None,
            date=None,
            category=None,
            is_parse_successful=False,
            confidence_score=score,
        )


def test_unreadable_receipt_rejects_high_confidence() -> None:
    with pytest.raises(ValidationError, match="güven skoru"):
        ReceiptParserResponse(
            normalized_ocr_text="Bozuk OCR",
            merchant=None,
            total_amount_minor=None,
            date=None,
            category=None,
            is_parse_successful=False,
            confidence_score=0.80,
        )


def test_total_amount_minor_cannot_be_negative() -> None:
    with pytest.raises(ValidationError):
        ReceiptParserResponse(
            normalized_ocr_text="Bozuk OCR",
            merchant=None,
            total_amount_minor=-1,
            date=None,
            category=None,
            is_parse_successful=False,
            confidence_score=0.1,
        )


def test_receipt_item_accepts_optional_pricing_and_tax_fields() -> None:
    result = ReceiptParserResponse.model_validate(
        {
            "normalized_ocr_text": "MARKET",
            "merchant": None,
            "total_amount_minor": None,
            "items": [
                {
                    "name": "Süt",
                    "price_minor": 1200,
                    "category": "Gıda",
                    "quantity": 2,
                    "unit_price_in_minor": 1200,
                    "tax_rate": 0.2,
                    "tax_amount_in_minor": 400,
                }
            ],
            "is_parse_successful": False,
            "confidence_score": 0.3,
        }
    )

    item = result.items[0]
    assert item.quantity == 2
    assert item.unit_price_in_minor == 1200
    assert item.tax_rate == 0.2
    assert item.tax_amount_in_minor == 400


def test_receipt_item_keeps_name_when_price_and_category_are_unknown() -> None:
    result = ReceiptParserResponse.model_validate(
        {
            "normalized_ocr_text": "KISMEN OKUNAN URUN",
            "merchant": None,
            "total_amount_minor": None,
            "items": [{"name": "Kısmen Okunan Ürün"}],
            "is_parse_successful": False,
            "confidence_score": 0.3,
        }
    )

    item = result.items[0]
    assert item.name == "Kısmen Okunan Ürün"
    assert item.price_minor is None
    assert item.category is None


def test_normalized_ocr_text_cannot_be_blank() -> None:
    with pytest.raises(ValidationError):
        ReceiptParserResponse(
            normalized_ocr_text="",
            merchant=None,
            total_amount_minor=None,
            date=None,
            category=None,
            is_parse_successful=False,
            confidence_score=0.1,
        )
