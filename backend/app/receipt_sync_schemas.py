import uuid
from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


class ReceiptLineItemSyncRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    position: int = Field(ge=0)
    name: str = Field(min_length=1, max_length=500)
    total_amount_in_minor: int = Field(ge=0)
    quantity_milli: int | None = Field(default=None, gt=0)
    unit_price_in_minor: int | None = Field(default=None, ge=0)
    category: str | None = Field(default=None, max_length=64)


class ReceiptSyncRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_record_id: uuid.UUID
    merchant_name: str | None = Field(default=None, max_length=255)
    total_amount_in_minor: int = Field(gt=0)
    currency: str = Field(default="TRY", min_length=3, max_length=3)
    receipt_date: datetime
    category: str | None = Field(default=None, max_length=64)
    raw_ocr_text: str | None = Field(default=None, max_length=30_000)
    client_created_at: datetime
    client_updated_at: datetime
    line_items: list[ReceiptLineItemSyncRequest] = Field(min_length=1)

    @field_validator("receipt_date", "client_created_at", "client_updated_at")
    @classmethod
    def normalize_datetime(cls, value: datetime) -> datetime:
        return _as_utc(value)

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.strip().upper()

    @field_validator("line_items")
    @classmethod
    def reject_duplicate_positions(
        cls, value: list[ReceiptLineItemSyncRequest]
    ) -> list[ReceiptLineItemSyncRequest]:
        positions = [item.position for item in value]
        if len(positions) != len(set(positions)):
            raise ValueError("line item positions must be unique")
        return value

    @model_validator(mode="after")
    def validate_timestamps(self) -> "ReceiptSyncRequest":
        if self.client_updated_at < self.client_created_at:
            raise ValueError("client_updated_at cannot be before client_created_at")
        return self


class ReceiptLineItemSyncResponse(BaseModel):
    receipt_line_item_id: uuid.UUID
    position: int
    name: str
    total_amount_in_minor: int
    quantity_milli: int | None
    unit_price_in_minor: int | None


class ReceiptSyncResponse(BaseModel):
    receipt_id: uuid.UUID
    total_amount_in_minor: int
    line_items: list[ReceiptLineItemSyncResponse]
