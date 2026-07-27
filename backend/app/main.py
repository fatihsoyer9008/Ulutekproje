from fastapi import FastAPI
from app.core.config import settings

# GÜNCELLENEN IMPORT: ReceiptParserRequest eklendi
from app.schemas import ReceiptParserResponse, ReceiptItem, ReceiptParserRequest

app = FastAPI(title=settings.app_name, version="0.1.0")

@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    """Minimal endpoint used to verify the local server is running."""
    return {"status": "ok", "environment": settings.app_env}

# GÜNCELLENEN ENDPOINT: Parametre olarak request eklendi
@app.post("/api/v1/parse-receipt", response_model=ReceiptParserResponse)
async def parse_receipt_dummy(request: ReceiptParserRequest):
    """
    Frontend testleri için geçici (dummy) veri döner.
    Gelen OCR metnini (request.ocr_text) şimdilik işlemiyoruz, sadece sahte yanıt dönüyoruz.
    """
    return ReceiptParserResponse(
        store_name="Örnek Süpermarket",
        total_amount_minor=2550, 
        items=[
            ReceiptItem(name="Süt 1L", price_minor=1200, category="Gıda"),
            ReceiptItem(name="Tam Buğday Ekmek", price_minor=1350, category="Fırın")
        ]
    )