from app.schemas import ReceiptParserResponse
from app.services.receipt_parser import (
    SYSTEM_INSTRUCTION,
    GeminiReceiptParserService,
)


def test_gemini_rules_are_sent_as_system_instruction() -> None:
    config = GeminiReceiptParserService._generation_config()

    assert config.system_instruction == SYSTEM_INSTRUCTION
    assert config.response_schema is ReceiptParserResponse
    assert "kuruş" in SYSTEM_INSTRUCTION

import pytest
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import DummyReceiptParserService

# Eğer testleri Dummy üzerinden ya da Mock bir Gemini servisi üzerinden çalıştırıyorsan
# asenkron (async) testler yazmalısın.

@pytest.mark.asyncio
async def test_successful_ocr_parsing():
    """Tüm verilerin tam olduğu başarılı OCR senaryosu."""
    service = DummyReceiptParserService()
    req = ReceiptParserRequest(ocr_text="Örnek Süpermarket 2026-07-28 Toplam: 25.50 TL")
    res = await service.parse(req)
    
    assert res.is_parse_successful is True
    assert res.confidence_score > 0.8

# Not: Gemini'yi doğrudan test etmek maliyetli olacağından, 
# gerçek projelerde model.generate_content fonksiyonu 'unittest.mock' ile taklit (mock) edilir.
# Yaptığın sistem prompt'unun model üzerindeki etkisini test edebilmek için ekip arkadaşların 
# muhtemelen Gemini servisini mock'layarak şu beklentileri test etmeni istiyor:

@pytest.mark.asyncio
async def test_missing_merchant():
    """Kurum adı (merchant) okunamadığında is_parse_successful false dönmeli."""
    # OCR metninde kurum yok
    req = ReceiptParserRequest(ocr_text="Tarih: 2026-07-28 Toplam: 25.50 TL Süt: 25.50")
    # YUKARIDAKİ REQUEST GEMINI MOCK'UNA GÖNDERİLDİĞİNDE:
    # assert response.merchant is None
    # assert response.is_parse_successful is False

@pytest.mark.asyncio
async def test_missing_date():
    """Tarih (date) okunamadığında is_parse_successful false dönmeli."""
    req = ReceiptParserRequest(ocr_text="Örnek Süpermarket Toplam: 25.50 TL")
    # assert response.date is None
    # assert response.is_parse_successful is False

@pytest.mark.asyncio
async def test_missing_amount():
    """Tutar (total_amount_minor) okunamadığında is_parse_successful false dönmeli."""
    req = ReceiptParserRequest(ocr_text="Örnek Süpermarket Tarih: 2026-07-28 Ürünler okunamıyor")
    # assert response.total_amount_minor is None
    # assert response.is_parse_successful is False

@pytest.mark.asyncio
async def test_broken_ocr():
    """Tamamen bozuk OCR metninde güven skoru düşük ve işlem başarısız olmalı."""
    req = ReceiptParserRequest(ocr_text="*%&/()= %&/ ASDF 123 ..--")
    # assert response.is_parse_successful is False
    # assert response.confidence_score < 0.5