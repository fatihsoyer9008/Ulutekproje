from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.ocr_security import OCR_TEXT_MAX_LENGTH, validate_ocr_text


class ReceiptParserRequest(BaseModel):
    ocr_text: str = Field(min_length=1, max_length=OCR_TEXT_MAX_LENGTH)

    @field_validator("ocr_text")
    @classmethod
    def validate_ocr_text(cls, value: str) -> str:
        return validate_ocr_text(value)


class ReceiptItem(BaseModel):
    name: str = Field(min_length=1)
    # A line can still be useful when OCR only recognizes its product name.
    # Keep uncertain values null instead of forcing Gemini to invent them or
    # discard the complete line item.
    price_minor: Optional[int] = Field(
        default=None,
        ge=0,
        description="Kuruş cinsinden ürün fiyatı",
    )
    category: Optional[str] = Field(default=None, min_length=1)
    total_amount_minor: Optional[int] = Field(default=None, ge=0)
    quantity: Optional[float] = Field(default=None, ge=0)
    unit_price_in_minor: Optional[int] = Field(default=None, ge=0)
    tax_rate: Optional[float] = Field(default=None, ge=0)
    tax_amount_in_minor: Optional[int] = Field(default=None, ge=0)


class ReceiptParserResponse(BaseModel):
    normalized_ocr_text: str = Field(
        min_length=1,
        description="Satır sırası ve açık OCR hataları güvenli biçimde düzeltilmiş metin.",
    )
    merchant: Optional[str] = Field(default=None, min_length=1)
    total_amount_minor: Optional[int] = Field(default=None, ge=0)

    currency: Literal["TRY"] = "TRY"
    date: Optional[datetime] = None
    category: Optional[str] = None
    items: list[ReceiptItem] = Field(default_factory=list)

    is_parse_successful: bool = Field(
        ...,
        description="Kurum, tarih ve tutar tam ve doğru okunabildiyse true, aksi halde false.",
    )
    confidence_score: float = Field(
        ...,
        ge=0,
        le=1,
        description="OCR metninden çıkarılan verilerin genel güvenilirlik skoru (0.0 ile 1.0 arası).",
    )

    @model_validator(mode="after")
    def validate_success_consistency(self) -> "ReceiptParserResponse":
        required_values = (self.merchant, self.date, self.total_amount_minor)
        if self.is_parse_successful and any(value is None for value in required_values):
            raise ValueError(
                "Başarılı ayrıştırma için kurum, tarih ve toplam tutar zorunludur"
            )
        if (
            all(value is None for value in required_values)
            and self.confidence_score > 0.30
        ):
            raise ValueError(
                "Hiçbir temel alan okunamadığında güven skoru en fazla 0.30 olabilir"
            )
        return self
