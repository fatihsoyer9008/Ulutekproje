from typing import Protocol

from google import genai
from google.genai import types

from app.schemas import (
    ReceiptItem,
    ReceiptParserRequest,
    ReceiptParserResponse,
)

# Gemini'nin her istek için izlemesi gereken sabit kurallar. Kullanıcıdan
# gelen OCR metni bu talimata karıştırılmaz; yalnızca `contents` alanına gider.
SYSTEM_INSTRUCTION = """
Sen Türkçe perakende fişlerini ayrıştıran bir asistansın.

OCR metninden yalnızca fişte açıkça bulunan bilgileri çıkar. Tahmin veya
uydurma yapma. Tüm para değerlerini TL değil kuruş cinsinden tam sayı olarak
döndür. Tarih belirsizse null kullan. Ayrıştırma güvenilir değilse
is_parse_successful=false yap ve gerçekçi bir confidence_score belirle.

Yanıtı her zaman tanımlanan JSON şemasına uygun üret.
""".strip()


class ReceiptParserError(RuntimeError):
    """Raised when a receipt cannot be parsed by the configured provider."""


class ReceiptParserService(Protocol):
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        """Parse normalized OCR text into the shared receipt contract."""


class DummyReceiptParserService:
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        del request
        return ReceiptParserResponse(
            merchant="Örnek Süpermarket",
            total_amount_minor=2550,
            currency="TRY",
            date=None,
            category="Market",
            confidence_score=0.99,
            is_parse_successful=True,
            items=[
                ReceiptItem(name="Süt 1L", price_minor=1200, category="Gıda"),
                ReceiptItem(
                    name="Tam Buğday Ekmek",
                    price_minor=1350,
                    category="Fırın",
                ),
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
