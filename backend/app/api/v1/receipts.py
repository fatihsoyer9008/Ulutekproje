from datetime import datetime, timezone

from fastapi import APIRouter

from app.models import ReceiptItem, ReceiptParseRequest, ReceiptParseResponse

router = APIRouter(prefix="/api/v1", tags=["receipts"])


@router.post("/parse-receipt", response_model=ReceiptParseResponse)
def parse_receipt(_: ReceiptParseRequest | None = None) -> ReceiptParseResponse:
    """Return deterministic sample data until the AI parser is connected."""

    items = [
        ReceiptItem(name="Süt", quantity=1, unit_price_minor=3250, total_price_minor=3250),
        ReceiptItem(name="Tam Buğday Ekmeği", quantity=1, unit_price_minor=2250, total_price_minor=2250),
        ReceiptItem(name="Zeytinyağı", quantity=1, unit_price_minor=26500, total_price_minor=26500),
    ]
    return ReceiptParseResponse(
        merchant_name="Örnek Market",
        purchased_at=datetime(2026, 7, 27, 14, 30, tzinfo=timezone.utc),
        currency="TRY",
        subtotal_minor=31000,
        tax_minor=1760,
        total_minor=32760,
        items=items,
        confidence=0.98,
        raw_text="Örnek Market\\nSüt 32,50\\nTam Buğday Ekmeği 22,50\\nZeytinyağı 265,00",
    )

