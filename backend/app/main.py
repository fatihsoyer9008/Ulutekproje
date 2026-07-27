from fastapi import Depends, FastAPI, HTTPException, status

from app.core.config import settings
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import (
    DummyReceiptParserService,
    GeminiReceiptParserService,
    ReceiptParserError,
    ReceiptParserService,
)

app = FastAPI(title=settings.app_name, version="0.1.0")

@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    """Minimal endpoint used to verify the local server is running."""
    return {"status": "ok", "environment": settings.app_env}

def get_receipt_parser_service() -> ReceiptParserService:
    if settings.use_dummy_parser:
        return DummyReceiptParserService()

    if settings.gemini_api_key is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GEMINI_API_KEY yapılandırılmamış",
        )

    return GeminiReceiptParserService(
        api_key=settings.gemini_api_key.get_secret_value(),
        model=settings.gemini_model,
    )


@app.post("/api/v1/parse-receipt", response_model=ReceiptParserResponse)
async def parse_receipt(
    request: ReceiptParserRequest,
    parser: ReceiptParserService = Depends(get_receipt_parser_service),
) -> ReceiptParserResponse:
    try:
        return await parser.parse(request)
    except ReceiptParserError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Fiş metni yapay zekâ servisi tarafından ayrıştırılamadı",
        ) from exc
