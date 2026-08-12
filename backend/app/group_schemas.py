import enum
import uuid
from datetime import UTC, datetime
from decimal import Decimal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_serializer,
    field_validator,
    model_validator,
)

from app.models.group import GroupRole


class FastSplitType(str, enum.Enum):
    equal = "EQUAL"
    percentage = "PERCENTAGE"
    exact = "EXACT"


class ExpenseParticipantRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: uuid.UUID
    percentage: Decimal | None = Field(default=None, ge=0, le=100)
    amount_in_minor: int | None = Field(default=None, ge=0)


class GroupExpenseCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str = Field(min_length=1, max_length=255)
    note: str | None = None
    expense_date: datetime
    total_amount_in_minor: int = Field(gt=0)
    currency: str = Field(default="TRY", min_length=3, max_length=3)
    paid_by_id: uuid.UUID
    split_type: FastSplitType
    participants: list[ExpenseParticipantRequest] = Field(min_length=1)

    @field_validator("title", mode="before")
    @classmethod
    def normalize_title(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.strip().upper()

    @model_validator(mode="after")
    def validate_split_fields(self) -> "GroupExpenseCreateRequest":
        ids = [item.user_id for item in self.participants]
        if len(ids) != len(set(ids)):
            raise ValueError("participants must contain unique users")
        for item in self.participants:
            if self.split_type is FastSplitType.percentage:
                if item.percentage is None or item.amount_in_minor is not None:
                    raise ValueError("PERCENTAGE requires percentage only")
            elif self.split_type is FastSplitType.exact:
                if item.amount_in_minor is None or item.percentage is not None:
                    raise ValueError("EXACT requires amount_in_minor only")
            elif item.percentage is not None or item.amount_in_minor is not None:
                raise ValueError("EQUAL participants cannot specify a share")
        return self


class ExpenseShareResponse(BaseModel):
    user_id: uuid.UUID
    amount_in_minor: int


class GroupExpenseResponse(BaseModel):
    id: uuid.UUID
    group_id: uuid.UUID
    paid_by_id: uuid.UUID
    created_by_id: uuid.UUID
    title: str
    note: str | None
    expense_date: datetime
    total_amount_in_minor: int
    currency: str
    split_type: FastSplitType
    shares: list[ExpenseShareResponse]

    @field_serializer("expense_date", when_used="json")
    def serialize_expense_date(self, value: datetime) -> str:
        normalized = value.replace(tzinfo=UTC) if value.tzinfo is None else value
        return normalized.isoformat().replace("+00:00", "Z")


class GroupExpenseEnvelope(BaseModel):
    expense: GroupExpenseResponse


class GroupCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=1000)
    currency: str = Field(min_length=3, max_length=3)

    @field_validator("name", mode="before")
    @classmethod
    def normalize_name(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @field_validator("currency")
    @classmethod
    def validate_currency(cls, value: str) -> str:
        normalized = value.strip().upper()
        if normalized != "TRY":
            raise ValueError("currency must be TRY")
        return normalized


class GroupUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=1000)

    @field_validator("name", mode="before")
    @classmethod
    def normalize_name(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @model_validator(mode="after")
    def validate_changes(self) -> "GroupUpdateRequest":
        if not self.model_fields_set:
            raise ValueError("at least one field must be provided")
        if "name" in self.model_fields_set and self.name is None:
            raise ValueError("name cannot be null")
        return self


class GroupMemberResponse(BaseModel):
    group_id: uuid.UUID
    user_id: uuid.UUID
    display_name: str
    role: GroupRole
    joined_at: datetime
    left_at: datetime | None


class GroupMemberCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID
    role: GroupRole = GroupRole.member


class GroupMemberRoleUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    role: GroupRole


class GroupMemberEnvelope(BaseModel):
    member: GroupMemberResponse


class GroupSummaryResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    currency: str
    member_count: int
    current_user_role: GroupRole
    created_by: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    archived_at: datetime | None


class GroupDetailResponse(GroupSummaryResponse):
    members: list[GroupMemberResponse]


class GroupResponse(BaseModel):
    group: GroupDetailResponse


class GroupsResponse(BaseModel):
    groups: list[GroupSummaryResponse]
