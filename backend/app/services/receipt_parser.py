from typing import Protocol
from google import genai
from google.genai import types

from app.schemas import ReceiptItem, ReceiptParserRequest, ReceiptParserResponse

# Sistem talimatı alan isimleri (merchant, total_amount_minor) ile güncellendi
SYSTEM_INSTRUCTION = """
Sen bir finansal veri ayrıştırıcısısın. Görevin sana verilen karmaşık OCR fiş metinlerini analiz edip istenen JSON şemasına uygun olarak döndürmektir. 

KESİN KURALLAR:
1. HALÜSİNASYON YASAKTIR: Sadece ve sadece OCR metninde geçen bilgileri kullan. Uydurma yapma.
2. BAŞARI DURUMU (is_parse_successful): Eğer fişin ait olduğu kurum (merchant), işlem tarihi (date) ve toplam tutar (total_amount_minor) net bir şekilde metinden çıkarılabiliyorsa is_parse_successful değerini true yap. Eksikse false yap.
3. GÜVEN SKORU (confidence_score): Verilerin kesinliğine göre 0.0 ile 1.0 arasında bir değer ver. Parasal tutarları kuruş (int) olarak yaz.
""".strip()

class ReceiptParserError(RuntimeError):
    pass

class ReceiptParserService(Protocol):
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        pass

class DummyReceiptParserService:
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        del request
        # Eski sözleşme değerlerine geri dönüldü
        return ReceiptParserResponse(
            merchant="Örnek Süpermarket",
            total_amount_minor=2550,
            currency="TRY",
            date="2026-07-28",
            category="Market",
            confidence_score=0.99,
            is_parse_successful=True,
            items=[
                ReceiptItem(name="Süt 1L", price_minor=1200, category="Gıda"),
                ReceiptItem(name="Ekmek", price_minor=1350, category="Fırın"),
            ],
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
