from typing import Optional
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
    store_name: Optional[str] = Field(None, alias="storeName")
    date: Optional[str] = Field(None, alias="receiptDate")
    category: Optional[str] = Field(None, alias="category")
    total_amount: Optional[int] = Field(None, alias="totalAmount")
    
    # Yeni eklenen "MA" görev alanları
    is_parse_successful: bool = Field(
        ..., 
        alias="isParseSuccessful", 
        description="Firma, tarih ve tutar tam ve doğru okunabildiyse true, aksi halde false."
    )
    confidence_score: float = Field(
        ..., 
        alias="confidenceScore", 
        description="OCR metninden çıkarılan verilerin genel güvenilirlik skoru (0.0 ile 1.0 arası)."
    )

    class Config:
        populate_by_name = True