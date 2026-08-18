import uuid
from datetime import UTC, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

N8nWebhookEventType = Literal[
    "receipt.parsed",
    "group_expense.created",
    "settlement.completed",
    "group.invitation.created",
    "system.healthcheck.failed",
    "backup.failed",
]


class N8nWebhookEnvelope(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_type: N8nWebhookEventType
    event_id: uuid.UUID
    occurred_at: datetime
    schema_version: int = Field(gt=0)
    data: dict[str, Any] = Field(default_factory=dict)


class ReceiptParsedEventData(BaseModel):
    """n8n bir e-postadan (dekont/fiş/borç belgesi) çıkardığı veriyi taşır.

    Belge kaynağı FişKon uygulaması değil (fiziksel cihaz/OCR akışı yok),
    bu yüzden kullanıcı `client_record_id`/`installation_id` yerine
    e-posta adresiyle eşleştirilir; kayıt bu veriyle yeniden oluşturulur,
    var olan bir kayıt aranmaz.
    """

    model_config = ConfigDict(extra="ignore")

    email: EmailStr
    merchant_name: str | None = Field(default=None, max_length=255)
    total_amount_in_minor: int | None = Field(default=None, ge=0)
    currency: str = Field(default="TRY", min_length=3, max_length=3)
    receipt_date: datetime | None = None
    category: str | None = Field(default=None, max_length=64)
    normalized_ocr_text: str | None = Field(default=None, max_length=30_000)

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.strip().upper()

    @field_validator("receipt_date")
    @classmethod
    def normalize_receipt_date(cls, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        return value if value.tzinfo is not None else value.replace(tzinfo=UTC)


class N8nWebhookEventResponse(BaseModel):
    event_id: uuid.UUID
    status: Literal["accepted", "created"]
