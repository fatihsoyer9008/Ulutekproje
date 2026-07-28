import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from datetime import datetime

from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import (
    SYSTEM_INSTRUCTION,
    GeminiReceiptParserService,
    DummyReceiptParserService,
)

# 1. Mevcut kural testin gayet iyi, aynen koruyoruz
def test_gemini_rules_are_sent_as_system_instruction() -> None:
    config = GeminiReceiptParserService._generation_config()
    assert config.system_instruction == SYSTEM_INSTRUCTION
    assert config.response_schema is ReceiptParserResponse
    assert "kuruş" in SYSTEM_INSTRUCTION

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
        '{"merchant": "Örnek Süpermarket", "date": "2026-07-28T00:00:00", "total_amount_minor": 2550, "currency": "TRY", "is_parse_successful": true, "confidence_score": 0.95, "items": []}'
    )
    
    service = GeminiReceiptParserService(api_key="test-key", model="gemini-2.5-flash")
    req = ReceiptParserRequest(ocr_text="Örnek Süpermarket 2026-07-28 Toplam: 25.50 TL")
    res = await service.parse(req)
    
    # Assert (Doğrulama) işlemleri
    assert res.merchant == "Örnek Süpermarket"
    assert res.date == datetime(2026, 7, 28)
    assert res.total_amount_minor == 2550
    assert res.is_parse_successful is True
    assert res.confidence_score > 0.8


# 3. Code Review'da İstenen Eksik Alan Testleri
@pytest.mark.asyncio
@patch("app.services.receipt_parser.genai.Client")
async def test_missing_merchant(mock_client_class):
    """Kurum adı (merchant) okunamadığında is_parse_successful false dönmeli."""
    mock_client_class.return_value = create_mock_gemini_client(
        '{"merchant": null, "date": "2026-07-28T00:00:00", "total_amount_minor": 2550, "currency": "TRY", "is_parse_successful": false, "confidence_score": 0.7, "items": []}'
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
        '{"merchant": "Örnek Süpermarket", "date": null, "total_amount_minor": 2550, "currency": "TRY", "is_parse_successful": false, "confidence_score": 0.7, "items": []}'
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
        '{"merchant": "Örnek Süpermarket", "date": "2026-07-28T00:00:00", "total_amount_minor": null, "currency": "TRY", "is_parse_successful": false, "confidence_score": 0.6, "items": []}'
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
        '{"merchant": null, "date": null, "total_amount_minor": null, "currency": "TRY", "is_parse_successful": false, "confidence_score": 0.1, "items": []}'
    )
    
    service = GeminiReceiptParserService(api_key="test-key", model="gemini-2.5-flash")
    req = ReceiptParserRequest(ocr_text="*%&/()= %&/ ASDF 123 ..--")
    res = await service.parse(req)
    
    assert res.is_parse_successful is False
    assert res.confidence_score < 0.5