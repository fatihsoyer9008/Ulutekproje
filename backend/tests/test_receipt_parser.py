from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from pydantic import ValidationError

from app.prompts.receipt_parser import RECEIPT_PARSER_SYSTEM_INSTRUCTION
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import GeminiReceiptParserService

# 1. Mevcut kural testin gayet iyi, aynen koruyoruz
def test_gemini_rules_are_sent_as_system_instruction() -> None:
    config = GeminiReceiptParserService._generation_config()
    assert config.system_instruction == RECEIPT_PARSER_SYSTEM_INSTRUCTION
    assert config.response_schema is ReceiptParserResponse
    assert "normalized_ocr_text" in RECEIPT_PARSER_SYSTEM_INSTRUCTION
    assert "kuruş" in RECEIPT_PARSER_SYSTEM_INSTRUCTION

# --- MOCK YARDIMCI FONKSİYONU ---
# Kod tekrarını önlemek için Gemini'den dönecek JSON'u ayarlayan bir fonksiyon
def create_mock_gemini_client(json_text: str):
    mock_client_instance = MagicMock()
    mock_async_client = MagicMock()
    
    # ÇÖZÜM BURADA: aclose() metodunun asenkron olduğunu (AsyncMock) belirtiyoruz
    mock_async_client.aclose = AsyncMock() 
    
    mock_client_instance.aio = mock_async_client
    
    mock_generate_content = AsyncMock()
    mock_async_client.models.generate_content = mock_generate_content
    
    mock_response = MagicMock()
    mock_response.parsed = None
    mock_response.text = json_text
    mock_generate_content.return_value = mock_response
    
    return mock_client_instance


# 2. Başarılı OCR Senaryosu (Artık Dummy yerine gerçek servisi Mock ile test ediyoruz)
@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_successful_ocr_parsing(mock_client_class):
    """Tüm verilerin tam olduğu başarılı OCR senaryosu."""
    # Başarılı mock cevabı hazırlıyoruz
    mock_client_class.return_value = create_mock_gemini_client(
        '{"normalized_ocr_text": "Örnek Süpermarket\\nTarih: 2026-07-28\\nToplam: 25.50 TL", "merchant": "Örnek Süpermarket", "date": "2026-07-28T00:00:00", "total_amount_minor": 2550, "currency": "TRY", "is_parse_successful": true, "confidence_score": 0.95, "items": []}'
    )
    
    service = GeminiReceiptParserService(api_key="test-key", model="gemini-2.5-flash")
    req = ReceiptParserRequest(ocr_text="Örnek Süpermarket 2026-07-28 Toplam: 25.50 TL")
    res = await service.parse(req)
    
    # Assert (Doğrulama) işlemleri
    assert res.merchant == "Örnek Süpermarket"
    assert res.date == datetime(2026, 7, 28)
    assert res.total_amount_minor == 2550
    assert res.normalized_ocr_text.startswith("Örnek Süpermarket")
    assert res.is_parse_successful is True
    assert res.confidence_score > 0.8


# 3. Code Review'da İstenen Eksik Alan Testleri
@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_missing_merchant(mock_client_class):
    """Kurum adı (merchant) okunamadığında is_parse_successful false dönmeli."""
    mock_client_class.return_value = create_mock_gemini_client(
        '{"normalized_ocr_text": "Tarih: 2026-07-28\\nToplam: 25.50 TL", "merchant": null, "date": "2026-07-28T00:00:00", "total_amount_minor": 2550, "currency": "TRY", "is_parse_successful": false, "confidence_score": 0.7, "items": []}'
    )
    
    service = GeminiReceiptParserService(api_key="test-key", model="gemini-2.5-flash")
    req = ReceiptParserRequest(ocr_text="Tarih: 2026-07-28 Toplam: 25.50 TL Süt: 25.50")
    res = await service.parse(req)
    
    assert res.merchant is None
    assert res.is_parse_successful is False


@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_missing_date(mock_client_class):
    """Tarih (date) okunamadığında is_parse_successful false dönmeli."""
    mock_client_class.return_value = create_mock_gemini_client(
        '{"normalized_ocr_text": "Örnek Süpermarket\\nToplam: 25.50 TL", "merchant": "Örnek Süpermarket", "date": null, "total_amount_minor": 2550, "currency": "TRY", "is_parse_successful": false, "confidence_score": 0.7, "items": []}'
    )
    
    service = GeminiReceiptParserService(api_key="test-key", model="gemini-2.5-flash")
    req = ReceiptParserRequest(ocr_text="Örnek Süpermarket Toplam: 25.50 TL")
    res = await service.parse(req)
    
    assert res.date is None
    assert res.is_parse_successful is False


@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_missing_amount(mock_client_class):
    """Tutar (total_amount_minor) okunamadığında is_parse_successful false dönmeli."""
    mock_client_class.return_value = create_mock_gemini_client(
        '{"normalized_ocr_text": "Örnek Süpermarket\\nTarih: 2026-07-28", "merchant": "Örnek Süpermarket", "date": "2026-07-28T00:00:00", "total_amount_minor": null, "currency": "TRY", "is_parse_successful": false, "confidence_score": 0.6, "items": []}'
    )
    
    service = GeminiReceiptParserService(api_key="test-key", model="gemini-2.5-flash")
    req = ReceiptParserRequest(ocr_text="Örnek Süpermarket Tarih: 2026-07-28 Ürünler okunamıyor")
    res = await service.parse(req)
    
    assert res.total_amount_minor is None
    assert res.is_parse_successful is False


@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_broken_ocr(mock_client_class):
    """Tamamen bozuk OCR metninde güven skoru düşük ve işlem başarısız olmalı."""
    mock_client_class.return_value = create_mock_gemini_client(
        '{"normalized_ocr_text": "*%&/()= %&/ ASDF 123 ..--", "merchant": null, "date": null, "total_amount_minor": null, "currency": "TRY", "is_parse_successful": false, "confidence_score": 0.1, "items": []}'
    )
    
    service = GeminiReceiptParserService(api_key="test-key", model="gemini-2.5-flash")
    req = ReceiptParserRequest(ocr_text="*%&/()= %&/ ASDF 123 ..--")
    res = await service.parse(req)
    
    assert res.is_parse_successful is False
    assert res.confidence_score < 0.5


@pytest.mark.parametrize("missing_field", ["merchant", "date", "total_amount_minor"])
def test_successful_response_rejects_missing_required_field(missing_field):
    payload = {
        "normalized_ocr_text": "Örnek Süpermarket\nToplam: 25.50 TL",
        "merchant": "Örnek Süpermarket",
        "date": "2026-07-28T00:00:00",
        "total_amount_minor": 2550,
        "currency": "TRY",
        "category": "Market",
        "is_parse_successful": True,
        "confidence_score": 0.95,
        "items": [],
    }
    payload[missing_field] = None

    with pytest.raises(ValidationError):
        ReceiptParserResponse.model_validate(payload)


@pytest.mark.parametrize("score", [-0.01, 1.01])
def test_confidence_score_must_be_between_zero_and_one(score):
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


def test_total_amount_minor_cannot_be_negative():
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


def test_normalized_ocr_text_cannot_be_blank():
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
