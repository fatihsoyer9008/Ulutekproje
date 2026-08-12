"""Create typed expense extra amounts and shares.

Revision ID: 20260812_0008
Revises: 20260811_0007
Create Date: 2026-08-12
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260812_0008"
down_revision: str | None = "20260811_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "expense_extra_amounts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("expense_id", sa.Uuid(), nullable=False),
        sa.Column("type", sa.String(length=16), nullable=False),
        sa.Column("label", sa.String(length=255), nullable=True),
        sa.Column(
            "amount_in_minor",
            sa.BigInteger(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "type IN ('tax', 'tip', 'service_fee', 'other')",
            name="ck_expense_extra_amounts_type",
        ),
        sa.CheckConstraint(
            "amount_in_minor > 0",
            name="ck_expense_extra_amounts_amount_positive",
        ),
        sa.CheckConstraint(
            "type != 'other' OR " "(label IS NOT NULL AND length(trim(label)) > 0)",
            name="ck_expense_extra_amounts_other_label",
        ),
        sa.ForeignKeyConstraint(
            ["expense_id"],
            ["group_expenses.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "id",
            name="pk_expense_extra_amounts",
        ),
    )
    op.create_index(
        "ix_expense_extra_amounts_expense_id",
        "expense_extra_amounts",
        ["expense_id"],
    )

    op.create_table(
        "expense_extra_amount_shares",
        sa.Column(
            "extra_amount_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column(
            "amount_in_minor",
            sa.BigInteger(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "amount_in_minor >= 0",
            name="ck_expense_extra_amount_shares_amount_nonnegative",
        ),
        sa.ForeignKeyConstraint(
            ["extra_amount_id"],
            ["expense_extra_amounts.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "extra_amount_id",
            "user_id",
            name="pk_expense_extra_amount_shares",
        ),
    )
    op.create_index(
        "ix_expense_extra_amount_shares_user_id",
        "expense_extra_amount_shares",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_table("expense_extra_amount_shares")
    op.drop_table("expense_extra_amounts")
