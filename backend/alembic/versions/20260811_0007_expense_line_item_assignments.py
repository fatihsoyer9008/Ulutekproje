"""Create expense line-item assignments.

Revision ID: 20260811_0007
Revises: 20260811_0006
Create Date: 2026-08-11
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260811_0007"
down_revision: str | None = "20260811_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "expense_line_item_assignments",
        sa.Column("expense_id", sa.Uuid(), nullable=False),
        sa.Column(
            "receipt_line_item_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column(
            "amount_in_minor",
            sa.BigInteger(),
            nullable=False,
        ),
        sa.Column(
            "quantity_share_milli",
            sa.BigInteger(),
            nullable=True,
        ),
        sa.CheckConstraint(
            "amount_in_minor >= 0",
            name="ck_expense_line_item_assignments_amount_nonnegative",
        ),
        sa.CheckConstraint(
            "quantity_share_milli IS NULL OR quantity_share_milli > 0",
            name="ck_expense_line_item_assignments_quantity_positive",
        ),
        sa.ForeignKeyConstraint(
            ["expense_id"],
            ["group_expenses.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "expense_id",
            "receipt_line_item_id",
            "user_id",
            name="pk_expense_line_item_assignments",
        ),
    )
    op.create_index(
        "ix_expense_line_item_assignments_receipt_line_item_id",
        "expense_line_item_assignments",
        ["receipt_line_item_id"],
    )
    op.create_index(
        "ix_expense_line_item_assignments_user_id",
        "expense_line_item_assignments",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_table("expense_line_item_assignments")
