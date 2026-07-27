from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ReceiptItem(BaseModel):
    """A single line item parsed from a receipt.

    Monetary values are integers in the currency's minor unit (kuruş for TRY).
    """

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, examples=["Süt"])
    quantity: int = Field(ge=1, examples=[1])
    unit_price_minor: int = Field(ge=0, examples=[3250])
    total_price_minor: int = Field(ge=0, examples=[3250])


class ReceiptParseRequest(BaseModel):
    """Input accepted from the Flutter receipt scanner.

    The dummy implementation does not process the image yet, so both fields are optional.
    """

    model_config = ConfigDict(extra="forbid")

    image_base64: str | None = Field(default=None, min_length=1)
    file_name: str | None = Field(default=None, min_length=1, max_length=255)


class ReceiptParseResponse(BaseModel):
    """Stable JSON contract returned by receipt parsing.

    All monetary amounts use integer minor units; floats are deliberately excluded.
    """

    model_config = ConfigDict(extra="forbid")

    merchant_name: str = Field(min_length=1, examples=["Örnek Market"])
    purchased_at: datetime = Field(examples=["2026-07-27T14:30:00+03:00"])
    currency: str = Field(min_length=3, max_length=3, examples=["TRY"])
    subtotal_minor: int = Field(ge=0, examples=[31000])
    tax_minor: int = Field(ge=0, examples=[1760])
    total_minor: int = Field(ge=0, examples=[32760])
    items: list[ReceiptItem] = Field(min_length=1)
    confidence: float = Field(ge=0, le=1, examples=[0.98])
    raw_text: str | None = None

