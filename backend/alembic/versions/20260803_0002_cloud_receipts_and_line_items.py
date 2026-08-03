"""Create cloud receipt and line-item tables.

Revision ID: 20260803_0002
Revises: 20260729_0001
Create Date: 2026-08-03
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260803_0002"
down_revision: str | None = "20260729_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "cloud_receipts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("client_record_id", sa.Uuid(), nullable=False),
        sa.Column("installation_id_hash", sa.String(length=64), nullable=False),
        sa.Column("merchant_name", sa.String(length=255), nullable=True),
        sa.Column("total_amount_in_minor", sa.BigInteger(), nullable=True),
        sa.Column(
            "currency",
            sa.String(length=3),
            server_default="TRY",
            nullable=False,
        ),
        sa.Column("receipt_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("category", sa.String(length=64), nullable=True),
        sa.Column("normalized_ocr_text", sa.Text(), nullable=True),
        sa.Column("raw_ocr_text", sa.Text(), nullable=True),
        sa.Column(
            "is_parse_successful",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column("confidence_score", sa.Numeric(5, 4), nullable=True),
        sa.Column(
            "client_created_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "client_updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "total_amount_in_minor IS NULL OR total_amount_in_minor >= 0",
            name="ck_cloud_receipts_total_nonnegative",
        ),
        sa.CheckConstraint(
            "confidence_score IS NULL OR "
            "(confidence_score >= 0 AND confidence_score <= 1)",
            name="ck_cloud_receipts_confidence_range",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "client_record_id",
            name="uq_cloud_receipt_user_client_record",
        ),
    )
    op.create_index(
        "ix_cloud_receipts_user_date",
        "cloud_receipts",
        ["user_id", "receipt_date"],
    )

    op.create_table(
        "cloud_receipt_line_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("receipt_id", sa.Uuid(), nullable=False),
        sa.Column("client_record_id", sa.Uuid(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=500), nullable=False),
        sa.Column("price_in_minor", sa.BigInteger(), nullable=False),
        sa.Column("quantity", sa.Numeric(12, 3), nullable=True),
        sa.Column("unit_price_in_minor", sa.BigInteger(), nullable=True),
        sa.Column("tax_rate", sa.Numeric(5, 2), nullable=True),
        sa.Column("tax_amount_in_minor", sa.BigInteger(), nullable=True),
        sa.Column("category", sa.String(length=64), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "price_in_minor >= 0",
            name="ck_cloud_receipt_line_items_price_nonnegative",
        ),
        sa.CheckConstraint(
            "quantity IS NULL OR quantity > 0",
            name="ck_cloud_receipt_line_items_quantity_positive",
        ),
        sa.CheckConstraint(
            "unit_price_in_minor IS NULL OR unit_price_in_minor >= 0",
            name="ck_cloud_receipt_line_items_unit_price_nonnegative",
        ),
        sa.CheckConstraint(
            "tax_rate IS NULL OR (tax_rate >= 0 AND tax_rate <= 100)",
            name="ck_cloud_receipt_line_items_tax_rate_range",
        ),
        sa.CheckConstraint(
            "tax_amount_in_minor IS NULL OR tax_amount_in_minor >= 0",
            name="ck_cloud_receipt_line_items_tax_amount_nonnegative",
        ),
        sa.ForeignKeyConstraint(
            ["receipt_id"],
            ["cloud_receipts.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "receipt_id",
            "client_record_id",
            name="uq_cloud_receipt_line_item_client_record",
        ),
        sa.UniqueConstraint(
            "receipt_id",
            "position",
            name="uq_cloud_receipt_line_item_position",
        ),
    )
    op.create_index(
        "ix_cloud_receipt_line_items_receipt_id",
        "cloud_receipt_line_items",
        ["receipt_id"],
    )


def downgrade() -> None:
    op.drop_table("cloud_receipt_line_items")
    op.drop_table("cloud_receipts")
