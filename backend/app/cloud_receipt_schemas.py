import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class PendingReceiptOut(BaseModel):
    id: uuid.UUID
    merchant_name: Optional[str] = None
    total_amount_in_minor: Optional[int] = None
    currency: str
    receipt_date: Optional[datetime] = None
    category: Optional[str] = None
    normalized_ocr_text: Optional[str] = None
    created_at: datetime


class ApproveReceiptRequest(BaseModel):
    merchant_name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    total_amount_in_minor: Optional[int] = Field(default=None, ge=0)
    currency: Optional[str] = Field(default=None, min_length=3, max_length=3)
    receipt_date: Optional[datetime] = None
    category: Optional[str] = Field(default=None, max_length=64)

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: Optional[str]) -> Optional[str]:
        return value.upper() if value is not None else value
