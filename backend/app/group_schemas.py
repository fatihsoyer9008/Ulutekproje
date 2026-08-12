import enum
import uuid
from datetime import UTC, datetime

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
    equal = "equal"
    percentage = "percentage"
    fixed_amount = "fixed_amount"


class ExpenseSplitShareRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: uuid.UUID
    percentage_basis_points: int | None = Field(default=None, ge=0, le=10_000)
    amount_in_minor: int | None = Field(default=None, ge=0)


class ExpenseSplitRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    type: FastSplitType
    member_ids: list[uuid.UUID] | None = None
    shares: list[ExpenseSplitShareRequest] | None = None

    @model_validator(mode="after")
    def validate_shape(self) -> "ExpenseSplitRequest":
        if self.type is FastSplitType.equal:
            if not self.member_ids or self.shares is not None:
                raise ValueError("equal split requires member_ids only")
            ids = self.member_ids
        else:
            if not self.shares or self.member_ids is not None:
                raise ValueError("percentage/fixed_amount split requires shares only")
            ids = [share.user_id for share in self.shares]
            for share in self.shares:
                if self.type is FastSplitType.percentage:
                    if (
                        share.percentage_basis_points is None
                        or share.amount_in_minor is not None
                    ):
                        raise ValueError(
                            "percentage requires percentage_basis_points only"
                        )
                elif (
                    share.amount_in_minor is None
                    or share.percentage_basis_points is not None
                ):
                    raise ValueError("fixed_amount requires amount_in_minor only")
        if len(ids) != len(set(ids)):
            raise ValueError("split users must be unique")
        return self


class GroupExpenseCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str = Field(min_length=1, max_length=255)
    note: str | None = None
    expense_date: datetime
    total_amount_in_minor: int = Field(gt=0)
    currency: str = Field(default="TRY", min_length=3, max_length=3)
    receipt_id: uuid.UUID | None = None
    payer_user_id: uuid.UUID
    split: ExpenseSplitRequest

    @field_validator("title", mode="before")
    @classmethod
    def normalize_title(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.strip().upper()


class ExpenseShareResponse(BaseModel):
    expense_id: uuid.UUID
    user_id: uuid.UUID
    display_name: str
    amount_in_minor: int
    status: str
    settled_at: datetime | None


class GroupExpenseResponse(BaseModel):
    id: uuid.UUID
    group_id: uuid.UUID
    receipt_id: uuid.UUID | None
    payer_user_id: uuid.UUID
    created_by: uuid.UUID
    title: str
    note: str | None
    expense_date: datetime
    total_amount_in_minor: int
    currency: str
    split_type: str
    is_financially_locked: bool
    shares: list[ExpenseShareResponse]
    line_item_assignments: list[dict[str, object]]
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None

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
