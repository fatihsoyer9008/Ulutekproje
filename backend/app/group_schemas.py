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
    itemized = "itemized"


class ExpenseSplitShareRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: uuid.UUID
    percentage_basis_points: int | None = Field(default=None, ge=0, le=10_000)
    amount_in_minor: int | None = Field(default=None, ge=0)


class ItemizedLineItemShareRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: uuid.UUID
    amount_in_minor: int = Field(ge=0)
    quantity_share_milli: int | None = Field(default=None, gt=0)


class ItemizedLineItemRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    receipt_line_item_id: uuid.UUID
    shares: list[ItemizedLineItemShareRequest] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_users(self) -> "ItemizedLineItemRequest":
        user_ids = [share.user_id for share in self.shares]
        if len(user_ids) != len(set(user_ids)):
            raise ValueError("line-item share users must be unique")
        return self


class ExtraAmountShareRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: uuid.UUID
    amount_in_minor: int = Field(ge=0)


class ExpenseSplitRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    type: FastSplitType
    member_ids: list[uuid.UUID] | None = None
    shares: list[ExpenseSplitShareRequest] | None = None
    line_items: list[ItemizedLineItemRequest] | None = None
    extra_amount_shares: list[ExtraAmountShareRequest] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_shape(self) -> "ExpenseSplitRequest":
        if self.type is FastSplitType.itemized:
            if (
                not self.line_items
                or self.member_ids is not None
                or self.shares is not None
            ):
                raise ValueError("itemized split requires line_items only")
            line_item_ids = [item.receipt_line_item_id for item in self.line_items]
            if len(line_item_ids) != len(set(line_item_ids)):
                raise ValueError("itemized receipt line items must be unique")
            extra_user_ids = [share.user_id for share in self.extra_amount_shares]
            if len(extra_user_ids) != len(set(extra_user_ids)):
                raise ValueError("extra amount share users must be unique")
            return self

        if self.line_items is not None or self.extra_amount_shares:
            raise ValueError("fast split cannot include itemized fields")
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

    @model_validator(mode="after")
    def validate_itemized_receipt(self) -> "GroupExpenseCreateRequest":
        if self.split.type is FastSplitType.itemized and self.receipt_id is None:
            raise ValueError("itemized split requires receipt_id")
        return self


class ExpenseShareResponse(BaseModel):
    expense_id: uuid.UUID
    user_id: uuid.UUID
    display_name: str
    amount_in_minor: int
    status: str
    settled_at: datetime | None


class ReceiptLineItemAssignmentResponse(BaseModel):
    expense_id: uuid.UUID
    receipt_line_item_id: uuid.UUID
    user_id: uuid.UUID
    amount_in_minor: int
    quantity_share_milli: int | None


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
    line_item_assignments: list[ReceiptLineItemAssignmentResponse]
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
