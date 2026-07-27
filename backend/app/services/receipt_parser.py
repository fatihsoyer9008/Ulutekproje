from typing import Protocol

from google import genai
from google.genai import types

from app.schemas import (
    ReceiptItem,
    ReceiptParserRequest,
    ReceiptParserResponse,
)


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
                contents=self._build_prompt(request.ocr_text),
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=ReceiptParserResponse,
                ),
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
    def _build_prompt(ocr_text: str) -> str:
        return (
            "Aşağıdaki Türkçe fiş OCR metninden kurum, toplam tutar, tarih, "
            "kategori ve ürünleri çıkar. Tüm para değerlerini TL değil kuruş "
            "cinsinden tam sayı olarak döndür. Belirsiz tarih için null kullan. "
            "Sonuç güvenilir değilse is_parse_successful=false yap ve gerçekçi "
            "bir confidence_score belirle.\n\nOCR METNİ:\n"
            f"{ocr_text}"
        )
