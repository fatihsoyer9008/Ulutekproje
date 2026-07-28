from typing import Optional, List, Literal
from datetime import datetime
from pydantic import BaseModel, Field, field_validator

# 1. Geri bildirimde istenen ve backend'in başlaması için gereken Exception sınıfı
class ReceiptParserError(Exception):
    """Fiş parse edilirken oluşan hatalar için özel exception sınıfı."""
    pass

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
    # Sözleşme gereği ESKİ ALANLAR KORUNDU
    merchant: Optional[str] = None
    total_amount_minor: Optional[int] = None
    
    # 2. Tipler tam olarak Code Review'da istendiği gibi düzeltildi
    currency: Literal["TRY"] = "TRY" 
    date: Optional[datetime] = None  
    
    category: Optional[str] = None
    items: List[ReceiptItem] = Field(default_factory=list)
    
    # Yeni eklenen MA görev alanları
    is_parse_successful: bool = Field(
        ..., 
        description="Kurum, tarih ve tutar tam ve doğru okunabildiyse true, aksi halde false."
    )
    confidence_score: float = Field(
        ..., 
        description="OCR metninden çıkarılan verilerin genel güvenilirlik skoru (0.0 ile 1.0 arası)."
    )