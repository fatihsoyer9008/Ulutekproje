"""Add group expense creator and idempotency records.

Revision ID: 20260812_0009
Revises: 20260812_0008
Create Date: 2026-08-12
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260812_0009"
down_revision: str | None = "20260812_0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "group_expenses",
        sa.Column(
            "created_by",
            sa.Uuid(),
            nullable=True,
        ),
    )

    op.create_table(
        "group_expense_idempotency_records",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=False),
        sa.Column("expense_id", sa.Uuid(), nullable=True),
        sa.Column(
            "idempotency_key_hash",
            sa.String(length=64),
            nullable=False,
        ),
        sa.Column(
            "request_hash",
            sa.String(length=64),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["group_id"],
            ["groups.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["actor_user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["expense_id"],
            ["group_expenses.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "id",
            name="pk_group_expense_idempotency_records",
        ),
        sa.UniqueConstraint(
            "group_id",
            "actor_user_id",
            "idempotency_key_hash",
            name="uq_group_expense_idempotency_scope_key",
        ),
    )
    op.create_index(
        "ix_group_expense_idempotency_actor_user_id",
        "group_expense_idempotency_records",
        ["actor_user_id"],
    )
    op.create_index(
        "ix_group_expense_idempotency_expense_id",
        "group_expense_idempotency_records",
        ["expense_id"],
    )


def downgrade() -> None:
    op.drop_table("group_expense_idempotency_records")
    op.drop_column("group_expenses", "created_by")
