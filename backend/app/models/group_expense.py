import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ExpenseSplitType(str, enum.Enum):
    equal = "equal"
    percentage = "percentage"
    fixed_amount = "fixed_amount"
    itemized = "itemized"


class ExpenseShareStatus(str, enum.Enum):
    open = "open"
    partially_settled = "partially_settled"
    settled = "settled"


class GroupExpense(Base):
    __tablename__ = "group_expenses"
    __table_args__ = (
        CheckConstraint(
            "total_amount_in_minor >= 0",
            name="ck_group_expenses_total_nonnegative",
        ),
        CheckConstraint(
            "split_type IN " "('equal', 'percentage', 'fixed_amount', 'itemized')",
            name="ck_group_expenses_split_type",
        ),
        Index(
            "ix_group_expenses_group_deleted_date",
            "group_id",
            "deleted_at",
            "expense_date",
            "id",
        ),
        Index("ix_group_expenses_receipt_id", "receipt_id"),
        Index("ix_group_expenses_payer_user_id", "payer_user_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"),
        nullable=False,
    )
    receipt_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("cloud_receipts.id", ondelete="SET NULL"),
    )
    # Historical UUID intentionally outlives the User row.
    # Active membership is validated by the service before writes.
    payer_user_id: Mapped[uuid.UUID] = mapped_column(nullable=False)

    title: Mapped[str] = mapped_column(String(255), nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    expense_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    total_amount_in_minor: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
    )
    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        default="TRY",
        server_default="TRY",
    )
    split_type: Mapped[ExpenseSplitType] = mapped_column(
        Enum(
            ExpenseSplitType,
            name="ck_group_expenses_split_type",
            native_enum=False,
            create_constraint=False,
            validate_strings=True,
            length=16,
        ),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    group = relationship("Group", back_populates="expenses")
    receipt = relationship("CloudReceipt", back_populates="group_expenses")

    shares: Mapped[list["ExpenseShare"]] = relationship(
        back_populates="expense",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ExpenseShare.user_id",
    )
    line_item_assignments: Mapped[list["ExpenseLineItemAssignment"]] = relationship(
        back_populates="expense",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by=(
            "ExpenseLineItemAssignment.receipt_line_item_id, "
            "ExpenseLineItemAssignment.user_id"
        ),
    )


class ExpenseShare(Base):
    __tablename__ = "expense_shares"
    __table_args__ = (
        CheckConstraint(
            "amount_in_minor >= 0",
            name="ck_expense_shares_amount_nonnegative",
        ),
        CheckConstraint(
            "status IN ('open', 'partially_settled', 'settled')",
            name="ck_expense_shares_status",
        ),
        Index("ix_expense_shares_user_id", "user_id"),
    )

    # Composite primary key also enforces one share per user and expense.
    expense_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("group_expenses.id", ondelete="CASCADE"),
        primary_key=True,
    )
    # Historical UUID intentionally outlives the User row.
    # Active membership is validated by the service before writes.
    user_id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    amount_in_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    status: Mapped[ExpenseShareStatus] = mapped_column(
        Enum(
            ExpenseShareStatus,
            name="ck_expense_shares_status",
            native_enum=False,
            create_constraint=False,
            validate_strings=True,
            length=24,
        ),
        nullable=False,
        default=ExpenseShareStatus.open,
        server_default=ExpenseShareStatus.open.value,
    )
    settled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    expense: Mapped[GroupExpense] = relationship(back_populates="shares")


class ExpenseLineItemAssignment(Base):
    __tablename__ = "expense_line_item_assignments"
    __table_args__ = (
        CheckConstraint(
            "amount_in_minor >= 0",
            name="ck_expense_line_item_assignments_amount_nonnegative",
        ),
        CheckConstraint(
            "quantity_share_milli IS NULL OR quantity_share_milli > 0",
            name="ck_expense_line_item_assignments_quantity_positive",
        ),
        Index(
            "ix_expense_line_item_assignments_receipt_line_item_id",
            "receipt_line_item_id",
        ),
        Index(
            "ix_expense_line_item_assignments_user_id",
            "user_id",
        ),
    )

    expense_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("group_expenses.id", ondelete="CASCADE"),
        primary_key=True,
    )
    # Historical UUID intentionally outlives the receipt line-item row.
    # Receipt ownership and line-item existence are validated before writes.
    receipt_line_item_id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,
    )
    # Historical UUID intentionally outlives the User row.
    # Active membership is validated by the service before writes.
    user_id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    amount_in_minor: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
    )
    quantity_share_milli: Mapped[int | None] = mapped_column(BigInteger)

    expense: Mapped[GroupExpense] = relationship(back_populates="line_item_assignments")
