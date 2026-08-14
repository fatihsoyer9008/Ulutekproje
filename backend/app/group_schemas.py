import enum
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

    receipt_line_item_id: uuid.UUID | None = None
    receipt_line_item_position: int | None = Field(default=None, ge=0)
    shares: list[ItemizedLineItemShareRequest] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_line_reference(self) -> "ItemizedLineItemRequest":
        has_cloud_id = self.receipt_line_item_id is not None
        has_draft_position = self.receipt_line_item_position is not None
        if has_cloud_id == has_draft_position:
            raise ValueError(
                "Exactly one of receipt_line_item_id or "
                "receipt_line_item_position is required"
            )
        return self


class ReceiptDraftLineItemRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    position: int = Field(ge=0)
    name: str = Field(min_length=1, max_length=500)
    category: str | None = Field(default=None, max_length=64)
    quantity_milli: int | None = Field(default=None, gt=0)
    unit_price_in_minor: int | None = Field(default=None, ge=0)
    total_amount_in_minor: int = Field(gt=0)

    @field_validator("name", mode="before")
    @classmethod
    def normalize_name(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class ReceiptDraftRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    merchant_name: str | None = Field(default=None, max_length=255)
    category: str | None = Field(default=None, max_length=64)
    raw_ocr_text: str | None = None
    line_items: list[ReceiptDraftLineItemRequest] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_positions(self) -> "ReceiptDraftRequest":
        positions = [item.position for item in self.line_items]
        if len(positions) != len(set(positions)):
            raise ValueError("Receipt draft line positions must be unique")
        return self


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

    receipt_id: uuid.UUID | None = None
    receipt_draft: ReceiptDraftRequest | None = None
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

    @model_validator(mode="after")
    def validate_receipt_source(self) -> "ItemizedExpenseCreateRequest":
        has_cloud_receipt = self.receipt_id is not None
        has_receipt_draft = self.receipt_draft is not None
        if has_cloud_receipt == has_receipt_draft:
            raise ValueError("Exactly one of receipt_id or receipt_draft is required")

        for line_item in self.split.line_items:
            if has_cloud_receipt and line_item.receipt_line_item_id is None:
                raise ValueError(
                    "Cloud receipts require receipt_line_item_id references"
                )
            if has_receipt_draft and line_item.receipt_line_item_position is None:
                raise ValueError(
                    "Receipt drafts require receipt_line_item_position references"
                )

        return self


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


class GroupExpenseResponse(BaseModel):
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
    ) -> "GroupExpenseResponse":
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
    expense: GroupExpenseResponse


class GroupExpensesResponse(BaseModel):
    expenses: list[GroupExpenseResponse]
