from datetime import datetime

from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator

class ReceiptParserRequest(BaseModel):
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
    merchant: Optional[str] = Field(default=None, min_length=1)
    total_amount_minor: Optional[int] = Field(default=None, ge=0)
    
    currency: Literal["TRY"] = "TRY"
    date: Optional[datetime] = None
    category: Optional[str] = None
    items: list[ReceiptItem] = Field(default_factory=list)

    is_parse_successful: bool = Field(
        ..., 
        description="Kurum, tarih ve tutar tam ve doğru okunabildiyse true, aksi halde false."
    )
    confidence_score: float = Field(
        ...,
        ge=0,
        le=1,
        description="OCR metninden çıkarılan verilerin genel güvenilirlik skoru (0.0 ile 1.0 arası)."
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
