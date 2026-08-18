import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

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
    model_config = ConfigDict(extra="ignore")

    user_id: uuid.UUID
    client_record_id: uuid.UUID
    installation_id: str = Field(
        min_length=16,
        max_length=128,
        pattern=r"^[A-Za-z0-9._:-]+$",
    )


class N8nWebhookEventResponse(BaseModel):
    event_id: uuid.UUID
    status: Literal["accepted", "matched"]
