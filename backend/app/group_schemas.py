import uuid
from collections.abc import Mapping
from datetime import UTC, datetime
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_serializer,
    field_validator,
    model_validator,
)

from app.models.group import GroupRole
from app.models.group_expense import (
    ExpenseExtraAmount,
    ExpenseExtraAmountType,
    ExpenseShare,
    ExpenseShareStatus,
    ExpenseSplitType,
    GroupExpense,
)


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


class ItemizedLineItemShareRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID
    amount_in_minor: int = Field(ge=0)
    quantity_share_milli: int | None = Field(default=None, gt=0)


class ItemizedLineItemRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    receipt_line_item_id: uuid.UUID
    shares: list[ItemizedLineItemShareRequest] = Field(min_length=1)


class ExpenseExtraAmountShareRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID
    amount_in_minor: int = Field(ge=0)


class ExpenseExtraAmountRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: ExpenseExtraAmountType
    label: str | None = Field(default=None, max_length=255)
    amount_in_minor: int = Field(gt=0)
    shares: list[ExpenseExtraAmountShareRequest] = Field(min_length=1)

    @field_validator("label", mode="before")
    @classmethod
    def normalize_label(cls, value: object) -> object:
        if not isinstance(value, str):
            return value
        normalized = value.strip()
        return normalized or None

    @model_validator(mode="after")
    def validate_other_label(self) -> "ExpenseExtraAmountRequest":
        if self.type is ExpenseExtraAmountType.other and self.label is None:
            raise ValueError("label is required when type is other")
        return self


class ItemizedSplitRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal["itemized"]
    line_items: list[ItemizedLineItemRequest] = Field(min_length=1)
    extra_amounts: list[ExpenseExtraAmountRequest] = Field(default_factory=list)


class ItemizedExpenseCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    receipt_id: uuid.UUID
    payer_user_id: uuid.UUID
    title: str = Field(min_length=1, max_length=255)
    note: str | None = None
    expense_date: datetime
    total_amount_in_minor: int = Field(gt=0)
    currency: str = Field(min_length=3, max_length=3)
    split: ItemizedSplitRequest

    @field_validator("title", mode="before")
    @classmethod
    def normalize_title(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.strip().upper()


class ExpenseShareResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    expense_id: uuid.UUID
    user_id: uuid.UUID
    display_name: str
    amount_in_minor: int
    status: ExpenseShareStatus
    settled_at: datetime | None

    @classmethod
    def from_model(
        cls,
        share: ExpenseShare,
        *,
        display_name: str,
    ) -> "ExpenseShareResponse":
        return cls(
            expense_id=share.expense_id,
            user_id=share.user_id,
            display_name=display_name,
            amount_in_minor=share.amount_in_minor,
            status=share.status,
            settled_at=share.settled_at,
        )


class ExpenseLineItemAssignmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    expense_id: uuid.UUID
    receipt_line_item_id: uuid.UUID
    user_id: uuid.UUID
    amount_in_minor: int
    quantity_share_milli: int | None


class ExpenseExtraAmountShareResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    extra_amount_id: uuid.UUID
    user_id: uuid.UUID
    amount_in_minor: int


class ExpenseExtraAmountResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    expense_id: uuid.UUID
    type: ExpenseExtraAmountType
    label: str | None
    amount_in_minor: int
    shares: list[ExpenseExtraAmountShareResponse]

    @classmethod
    def from_model(
        cls,
        extra_amount: ExpenseExtraAmount,
    ) -> "ExpenseExtraAmountResponse":
        return cls(
            id=extra_amount.id,
            expense_id=extra_amount.expense_id,
            type=extra_amount.type,
            label=extra_amount.label,
            amount_in_minor=extra_amount.amount_in_minor,
            shares=[
                ExpenseExtraAmountShareResponse.model_validate(share)
                for share in sorted(
                    extra_amount.shares,
                    key=lambda share: str(share.user_id),
                )
            ],
        )


class GroupExpenseDataResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    group_id: uuid.UUID
    receipt_id: uuid.UUID | None
    payer_user_id: uuid.UUID
    created_by: uuid.UUID | None
    title: str
    note: str | None
    expense_date: datetime
    total_amount_in_minor: int
    currency: str
    split_type: ExpenseSplitType
    is_financially_locked: bool
    shares: list[ExpenseShareResponse]
    line_item_assignments: list[ExpenseLineItemAssignmentResponse]
    extra_amounts: list[ExpenseExtraAmountResponse]
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None

    @field_serializer(
        "expense_date",
        "created_at",
        "updated_at",
        "deleted_at",
        when_used="json",
    )
    def serialize_utc_datetime(
        self,
        value: datetime | None,
    ) -> str | None:
        if value is None:
            return None
        if value.tzinfo is None:
            value = value.replace(tzinfo=UTC)
        return value.astimezone(UTC).isoformat().replace("+00:00", "Z")

    @classmethod
    def from_model(
        cls,
        expense: GroupExpense,
        *,
        display_names: Mapping[uuid.UUID, str],
    ) -> "GroupExpenseDataResponse":
        return cls(
            id=expense.id,
            group_id=expense.group_id,
            receipt_id=expense.receipt_id,
            payer_user_id=expense.payer_user_id,
            created_by=expense.created_by,
            title=expense.title,
            note=expense.note,
            expense_date=expense.expense_date,
            total_amount_in_minor=expense.total_amount_in_minor,
            currency=expense.currency,
            split_type=expense.split_type,
            is_financially_locked=False,
            shares=[
                ExpenseShareResponse.from_model(
                    share,
                    display_name=display_names.get(
                        share.user_id,
                        "Silinmiş kullanıcı",
                    ),
                )
                for share in sorted(
                    expense.shares,
                    key=lambda share: str(share.user_id),
                )
            ],
            line_item_assignments=[
                ExpenseLineItemAssignmentResponse.model_validate(assignment)
                for assignment in sorted(
                    expense.line_item_assignments,
                    key=lambda assignment: (
                        str(assignment.receipt_line_item_id),
                        str(assignment.user_id),
                    ),
                )
            ],
            extra_amounts=[
                ExpenseExtraAmountResponse.from_model(extra_amount)
                for extra_amount in sorted(
                    expense.extra_amounts,
                    key=lambda extra_amount: str(extra_amount.id),
                )
            ],
            created_at=expense.created_at,
            updated_at=expense.updated_at,
            deleted_at=expense.deleted_at,
        )


class GroupExpenseEnvelope(BaseModel):
    expense: GroupExpenseDataResponse
