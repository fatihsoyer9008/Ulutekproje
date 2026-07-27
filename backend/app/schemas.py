from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator


class ReceiptParserRequest(BaseModel):
    """Cihaz içi OCR tarafından çıkarılan ham fiş metni."""

    ocr_text: str = Field(min_length=1, max_length=30_000)

    @field_validator("ocr_text")
    @classmethod
    def validate_ocr_text(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("OCR metni boş olamaz")
        return normalized


class ReceiptItem(BaseModel):
    name: str = Field(min_length=1)
    price_minor: int = Field(ge=0, description="Kuruş cinsinden ürün fiyatı")
    category: str = Field(min_length=1)


class ReceiptParserResponse(BaseModel):
    """Flutter ve veritabanı katmanlarının ortak fiş sözleşmesi."""

    merchant: str = Field(min_length=1)
    total_amount_minor: int = Field(ge=0, description="Kuruş cinsinden toplam")
    currency: Literal["TRY"] = "TRY"
    date: datetime | None = None
    category: str = Field(min_length=1)
    confidence_score: float = Field(ge=0, le=1)
    is_parse_successful: bool
    items: list[ReceiptItem] = Field(default_factory=list)
