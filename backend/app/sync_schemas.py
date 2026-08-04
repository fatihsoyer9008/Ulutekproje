import uuid
from datetime import UTC, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

InstallationId = str
SyncAction = Literal["upsert", "delete"]
SyncResultStatus = Literal["created", "updated", "unchanged", "deleted", "conflict"]


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


class TransactionSyncPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_record_id: uuid.UUID
    transaction_type: Literal["expense", "income"]
    amount_in_minor: int = Field(ge=0)
    category: str = Field(min_length=1, max_length=64)
    transaction_date: datetime
    merchant_name: str | None = Field(default=None, max_length=255)
    source: Literal["ocrRegex", "ocrLlm", "manual"]
    raw_ocr_text: str | None = Field(default=None, max_length=30_000)
    note: str | None = Field(default=None, max_length=1000)
    client_created_at: datetime
    client_updated_at: datetime

    @field_validator(
        "transaction_date",
        "client_created_at",
        "client_updated_at",
    )
    @classmethod
    def normalize_datetime(cls, value: datetime) -> datetime:
        return _as_utc(value)

    @model_validator(mode="after")
    def validate_client_timestamps(self) -> "TransactionSyncPayload":
        if self.client_updated_at < self.client_created_at:
            raise ValueError("client_updated_at cannot be before client_created_at")
        return self


class ClaimRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    installation_id: InstallationId = Field(
        min_length=16,
        max_length=128,
        pattern=r"^[A-Za-z0-9._:-]+$",
    )
    transactions: list[TransactionSyncPayload] = Field(min_length=1, max_length=500)

    @field_validator("transactions")
    @classmethod
    def reject_duplicate_records(
        cls,
        value: list[TransactionSyncPayload],
    ) -> list[TransactionSyncPayload]:
        record_ids = [item.client_record_id for item in value]
        if len(record_ids) != len(set(record_ids)):
            raise ValueError("transactions contains duplicate client_record_id values")
        return value


class PushOperation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    operation_id: str = Field(
        min_length=8,
        max_length=128,
        pattern=r"^[A-Za-z0-9._:-]+$",
    )
    action: SyncAction
    client_record_id: uuid.UUID
    client_updated_at: datetime
    transaction: TransactionSyncPayload | None = None

    @field_validator("client_updated_at")
    @classmethod
    def normalize_updated_at(cls, value: datetime) -> datetime:
        return _as_utc(value)

    @model_validator(mode="after")
    def validate_action_payload(self) -> "PushOperation":
        if self.action == "upsert":
            if self.transaction is None:
                raise ValueError("upsert operation requires transaction")
            if self.transaction.client_record_id != self.client_record_id:
                raise ValueError("operation and transaction record IDs must match")
            if self.transaction.client_updated_at != self.client_updated_at:
                raise ValueError("operation and transaction timestamps must match")
        elif self.transaction is not None:
            raise ValueError("delete operation cannot include transaction")
        return self


class PushRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    installation_id: InstallationId = Field(
        min_length=16,
        max_length=128,
        pattern=r"^[A-Za-z0-9._:-]+$",
    )
    operations: list[PushOperation] = Field(min_length=1, max_length=100)

    @field_validator("operations")
    @classmethod
    def reject_duplicate_operations(
        cls,
        value: list[PushOperation],
    ) -> list[PushOperation]:
        operation_ids = [item.operation_id for item in value]
        if len(operation_ids) != len(set(operation_ids)):
            raise ValueError("operations contains duplicate operation_id values")
        return value


class SyncResult(BaseModel):
    operation_id: str | None = None
    client_record_id: uuid.UUID
    status: SyncResultStatus
    server_updated_at: datetime


class ClaimResponse(BaseModel):
    owner_key: str
    results: list[SyncResult]


class PushResponse(BaseModel):
    results: list[SyncResult]


class SyncedTransaction(BaseModel):
    client_record_id: uuid.UUID
    transaction_type: str
    amount_in_minor: int
    category: str
    transaction_date: datetime
    merchant_name: str | None
    source: str
    raw_ocr_text: str | None
    note: str | None
    client_created_at: datetime
    client_updated_at: datetime
    server_updated_at: datetime
    deleted_at: datetime | None


class PullResponse(BaseModel):
    transactions: list[SyncedTransaction]
    next_cursor: str | None
    has_more: bool
