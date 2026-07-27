from fastapi import FastAPI

from app.core.config import settings
from app.schemas import ReceiptParserResponse, ReceiptItem


app = FastAPI(title=settings.app_name, version="0.1.0")

@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    """Minimal endpoint used to verify the local server is running."""

    return {"status": "ok", "environment": settings.app_env}


@app.post("/api/v1/parse-receipt", response_model=ReceiptParserResponse)
async def parse_receipt_dummy():
    """
    Frontend testleri için geçici (dummy) veri döner.
    """
    return ReceiptParserResponse(
        store_name="Örnek Süpermarket",
        total_amount_minor=2550, 
        items=[
            ReceiptItem(name="Süt 1L", price_minor=1200),
            ReceiptItem(name="Tam Buğday Ekmek", price_minor=1350)
        ]
    )