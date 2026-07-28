from typing import Protocol

from google import genai
from google.genai import types

from app.schemas import (
    ReceiptItem,
    ReceiptParserRequest,
    ReceiptParserResponse,
)

# MA Görevleri: Gemini'nin halüsinasyon görmesini engelleyen KATI KURALLAR
SYSTEM_INSTRUCTION = """
Sen bir finansal veri ayrıştırıcısısın. Görevin sana verilen karmaşık OCR fiş metinlerini analiz edip istenen JSON şemasına uygun olarak döndürmektir. 

KESİN KURALLAR (DİKKATLE UY):
1. HALÜSİNASYON YASAKTIR: Sadece ve sadece sana verilen OCR metninde geçen bilgileri kullan. Metinde açıkça yazmayan hiçbir tutarı, tarihi, kurumu veya kategoriyi kendi kendine tahmin etme veya uydurma. Eğer bir bilgi okunamıyorsa veya yoksa, o alanı null bırak.
2. BAŞARI DURUMU (is_parse_successful): Eğer fişin ait olduğu kurum (store_name), işlem tarihi (date) ve toplam tutar (total_amount) net bir şekilde metinden çıkarılabiliyorsa is_parse_successful değerini true yap. Bu üç ana bilgiden herhangi biri belirsiz, eksik veya okunamıyor ise bu değeri false yap.
3. GÜVEN SKORU (confidence_score): Metnin genel okunabilirliğine ve çıkardığın verilerin kesinliğine göre 0.0 ile 1.0 arasında bir confidence_score belirle. Tüm bilgiler netse 1.0, veriler bulanık veya çok fazla eksik alan varsa 0.5 ve altı puan ver. Parasal tutarların her zaman "int" (minor/kuruş) cinsinden olduğuna emin ol.
""".strip()


class ReceiptParserError(RuntimeError):
    """Raised when a receipt cannot be parsed by the configured provider."""


class ReceiptParserService(Protocol):
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        """Parse normalized OCR text into the shared receipt contract."""


class DummyReceiptParserService:
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        del request
        # DÜZELTME: Buradaki alanlar schemas.py içindeki ReceiptParserResponse
        # modelinle (store_name, date, category, total_amount) birebir aynı olmalı.
        return ReceiptParserResponse(
            store_name="Örnek Süpermarket",
            total_amount=2550, # Kuruş cinsinden (25.50 TL)
            date="2026-07-28",
            category="Market",
            confidence_score=0.99,
            is_parse_successful=True,
            # Not: ReceiptItem şemasını tanımlamıştın ama Response modeline eklememiştin.
            # O yüzden buradan items alanını şimdilik kaldırdık ki model patlamasın.
        )


class GeminiReceiptParserService:
    def __init__(self, *, api_key: str, model: str) -> None:
        self._api_key = api_key
        self._model = model

    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        client = genai.Client(api_key=self._api_key)
        async_client = client.aio
        try:
            response = await async_client.models.generate_content(
                model=self._model,
                contents=request.ocr_text,
                config=self._generation_config(),
            )

            if response.parsed is not None:
                return ReceiptParserResponse.model_validate(response.parsed)
            if response.text:
                return ReceiptParserResponse.model_validate_json(response.text)
            raise ReceiptParserError("Gemini boş bir yanıt döndürdü")
        except ReceiptParserError:
            raise
        except Exception as exc:
            raise ReceiptParserError("Gemini fiş metnini ayrıştıramadı") from exc
        finally:
            await async_client.aclose()

    @staticmethod
    def _generation_config() -> types.GenerateContentConfig:
        return types.GenerateContentConfig(
            system_instruction=SYSTEM_INSTRUCTION,
            response_mime_type="application/json",
            response_schema=ReceiptParserResponse,
        )