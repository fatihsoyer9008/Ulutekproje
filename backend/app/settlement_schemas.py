import uuid
from datetime import UTC, datetime

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StrictInt,
    field_serializer,
    field_validator,
)

from app.domain.debts import DebtSummary
from app.models.settlement import Settlement

_MAX_BIGINT = 9_223_372_036_854_775_807


class SettlementCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    from_user_id: uuid.UUID
    to_user_id: uuid.UUID
    amount_in_minor: StrictInt = Field(
        gt=0,
        le=_MAX_BIGINT,
    )
    currency: str = Field(min_length=3, max_length=3)
    settled_at: datetime
    note: str | None = Field(default=None, max_length=1000)

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.strip().upper()

    @field_validator("settled_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("settled_at must include a timezone")
        return value.astimezone(UTC)

    @field_validator("note", mode="before")
    @classmethod
    def normalize_note(cls, value: object) -> object:
        if not isinstance(value, str):
            return value
        normalized = value.strip()
        return normalized or None


class SettlementResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    group_id: uuid.UUID
    from_user_id: uuid.UUID
    to_user_id: uuid.UUID
    amount_in_minor: int
    currency: str
    settled_at: datetime
    note: str | None
    created_at: datetime

    @field_serializer(
        "settled_at",
        "created_at",
        when_used="json",
    )
    def serialize_utc_datetime(self, value: datetime) -> str:
        if value.tzinfo is None:
            value = value.replace(tzinfo=UTC)
        return value.astimezone(UTC).isoformat().replace("+00:00", "Z")

    @classmethod
    def from_model(cls, settlement: Settlement) -> "SettlementResponse":
        return cls.model_validate(settlement)


class SettlementEnvelope(BaseModel):
    settlement: SettlementResponse


class SettlementsResponse(BaseModel):
    settlements: list[SettlementResponse]


class DebtBalanceResponse(BaseModel):
    user_id: uuid.UUID
    display_name: str
    net_amount_in_minor: int


class DebtTransferResponse(BaseModel):
    from_user_id: uuid.UUID
    to_user_id: uuid.UUID
    amount_in_minor: int


class DebtSummaryResponse(BaseModel):
    group_id: uuid.UUID
    currency: str
    balances: list[DebtBalanceResponse]
    suggested_transfers: list[DebtTransferResponse]
    generated_at: datetime

    @field_serializer("generated_at", when_used="json")
    def serialize_generated_at(self, value: datetime) -> str:
        if value.tzinfo is None:
            value = value.replace(tzinfo=UTC)
        return value.astimezone(UTC).isoformat().replace("+00:00", "Z")

    @classmethod
    def from_domain(cls, summary: DebtSummary) -> "DebtSummaryResponse":
        return cls(
            group_id=uuid.UUID(summary.group_id),
            currency=summary.currency,
            balances=[
                DebtBalanceResponse(
                    user_id=uuid.UUID(balance.user_id),
                    display_name=balance.display_name,
                    net_amount_in_minor=balance.net_amount_in_minor,
                )
                for balance in summary.balances
            ],
            suggested_transfers=[
                DebtTransferResponse(
                    from_user_id=uuid.UUID(transfer.from_user_id),
                    to_user_id=uuid.UUID(transfer.to_user_id),
                    amount_in_minor=transfer.amount_in_minor,
                )
                for transfer in summary.suggested_transfers
            ],
            generated_at=summary.generated_at,
        )
