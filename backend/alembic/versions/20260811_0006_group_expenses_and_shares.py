"""Create group expenses and expense shares.

Revision ID: 20260811_0006
Revises: 20260810_0005
Create Date: 2026-08-11
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260811_0006"
down_revision: str | None = "20260810_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "group_expenses",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("receipt_id", sa.Uuid(), nullable=True),
        sa.Column("payer_user_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column(
            "expense_date",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "total_amount_in_minor",
            sa.BigInteger(),
            nullable=False,
        ),
        sa.Column(
            "currency",
            sa.String(length=3),
            server_default="TRY",
            nullable=False,
        ),
        sa.Column(
            "split_type",
            sa.String(length=16),
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
        sa.Column(
            "deleted_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.CheckConstraint(
            "total_amount_in_minor >= 0",
            name="ck_group_expenses_total_nonnegative",
        ),
        sa.CheckConstraint(
            "split_type IN " "('equal', 'percentage', 'fixed_amount', 'itemized')",
            name="ck_group_expenses_split_type",
        ),
        sa.ForeignKeyConstraint(
            ["group_id"],
            ["groups.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["receipt_id"],
            ["cloud_receipts.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_group_expenses_group_deleted_date",
        "group_expenses",
        ["group_id", "deleted_at", "expense_date", "id"],
    )
    op.create_index(
        "ix_group_expenses_receipt_id",
        "group_expenses",
        ["receipt_id"],
    )
    op.create_index(
        "ix_group_expenses_payer_user_id",
        "group_expenses",
        ["payer_user_id"],
    )

    op.create_table(
        "expense_shares",
        sa.Column("expense_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("amount_in_minor", sa.BigInteger(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=24),
            server_default="open",
            nullable=False,
        ),
        sa.Column(
            "settled_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.CheckConstraint(
            "amount_in_minor >= 0",
            name="ck_expense_shares_amount_nonnegative",
        ),
        sa.CheckConstraint(
            "status IN ('open', 'partially_settled', 'settled')",
            name="ck_expense_shares_status",
        ),
        sa.ForeignKeyConstraint(
            ["expense_id"],
            ["group_expenses.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(    
            "expense_id",
            "user_id",
            name="pk_expense_shares",
        ),
    )
    op.create_index(
        "ix_expense_shares_user_id",
        "expense_shares",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_table("expense_shares")
    op.drop_table("group_expenses")
