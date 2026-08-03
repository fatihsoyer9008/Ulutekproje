from typing import Protocol

from google import genai
from google.genai import types

from app.constants.ai_prompts import RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION
from app.schemas import ReceiptItem, ReceiptParserRequest, ReceiptParserResponse


class ReceiptParserError(RuntimeError):
    pass

class ReceiptParserService(Protocol):
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        pass

class DummyReceiptParserService:
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        return ReceiptParserResponse(
            normalized_ocr_text=request.ocr_text,
            merchant="Örnek Süpermarket",
            total_amount_minor=2550,
            currency="TRY",
            date="2026-07-28",
            category="Market",
            confidence_score=0.99,
            is_parse_successful=True,
            items=[
                ReceiptItem(
                    name="Süt 1L",
                    price_minor=1200,
                    unit_price_in_minor=1200,
                    quantity=1,
                    total_amount_minor=1200,
                    category="Gıda",
                ),
                ReceiptItem(
                    name="Ekmek",
                    price_minor=1350,
                    unit_price_in_minor=1350,
                    quantity=1,
                    total_amount_minor=1350,
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
            system_instruction=RECEIPT_EXTRACTION_SYSTEM_INSTRUCTION,
            response_mime_type="application/json",
            response_schema=ReceiptParserResponse,
        )
