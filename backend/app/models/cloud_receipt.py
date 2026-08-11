import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class CloudReceipt(Base):
    __tablename__ = "cloud_receipts"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "client_record_id",
            name="uq_cloud_receipt_user_client_record",
        ),
        CheckConstraint(
            "total_amount_in_minor IS NULL OR total_amount_in_minor >= 0",
            name="ck_cloud_receipts_total_nonnegative",
        ),
        CheckConstraint(
            "confidence_score IS NULL OR "
            "(confidence_score >= 0 AND confidence_score <= 1)",
            name="ck_cloud_receipts_confidence_range",
        ),
        Index(
            "ix_cloud_receipts_user_date",
            "user_id",
            "receipt_date",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    client_record_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    installation_id_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    merchant_name: Mapped[str | None] = mapped_column(String(255))
    total_amount_in_minor: Mapped[int | None] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        default="TRY",
        server_default="TRY",
    )
    receipt_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    category: Mapped[str | None] = mapped_column(String(64))
    normalized_ocr_text: Mapped[str | None] = mapped_column(Text)
    raw_ocr_text: Mapped[str | None] = mapped_column(Text)
    is_parse_successful: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    confidence_score: Mapped[Decimal | None] = mapped_column(Numeric(5, 4))
    client_created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    client_updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
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

    user = relationship("User", back_populates="cloud_receipts")
    line_items: Mapped[list["CloudReceiptLineItem"]] = relationship(
        back_populates="receipt",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="CloudReceiptLineItem.position",
    )
    group_expenses = relationship(
        "GroupExpense",
        back_populates="receipt",
        passive_deletes=True,
    )


class CloudReceiptLineItem(Base):
    __tablename__ = "cloud_receipt_line_items"
    __table_args__ = (
        UniqueConstraint(
            "receipt_id",
            "client_record_id",
            name="uq_cloud_receipt_line_item_client_record",
        ),
        UniqueConstraint(
            "receipt_id",
            "position",
            name="uq_cloud_receipt_line_item_position",
        ),
        CheckConstraint(
            "price_in_minor >= 0",
            name="ck_cloud_receipt_line_items_price_nonnegative",
        ),
        CheckConstraint(
            "quantity IS NULL OR quantity > 0",
            name="ck_cloud_receipt_line_items_quantity_positive",
        ),
        CheckConstraint(
            "unit_price_in_minor IS NULL OR unit_price_in_minor >= 0",
            name="ck_cloud_receipt_line_items_unit_price_nonnegative",
        ),
        CheckConstraint(
            "tax_rate IS NULL OR (tax_rate >= 0 AND tax_rate <= 100)",
            name="ck_cloud_receipt_line_items_tax_rate_range",
        ),
        CheckConstraint(
            "tax_amount_in_minor IS NULL OR tax_amount_in_minor >= 0",
            name="ck_cloud_receipt_line_items_tax_amount_nonnegative",
        ),
        Index("ix_cloud_receipt_line_items_receipt_id", "receipt_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    receipt_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("cloud_receipts.id", ondelete="CASCADE"),
        nullable=False,
    )
    client_record_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    name: Mapped[str] = mapped_column(String(500), nullable=False)
    price_in_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    quantity: Mapped[Decimal | None] = mapped_column(Numeric(12, 3))
    unit_price_in_minor: Mapped[int | None] = mapped_column(BigInteger)
    tax_rate: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    tax_amount_in_minor: Mapped[int | None] = mapped_column(BigInteger)
    category: Mapped[str | None] = mapped_column(String(64))
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

    receipt: Mapped[CloudReceipt] = relationship(back_populates="line_items")
