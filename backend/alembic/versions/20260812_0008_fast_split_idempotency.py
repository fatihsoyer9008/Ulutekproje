"""Add Fast Split creator and idempotency fields.

Revision ID: 20260812_0008
Revises: 20260811_0007
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260812_0008"
down_revision: str | None = "20260811_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "group_expenses", sa.Column("created_by_id", sa.Uuid(), nullable=True)
    )
    op.add_column("group_expenses", sa.Column("idempotency_key", sa.String(255)))
    op.add_column(
        "group_expenses", sa.Column("idempotency_request_hash", sa.String(64))
    )
    op.execute("UPDATE group_expenses SET created_by_id = payer_user_id")
    op.alter_column("group_expenses", "created_by_id", nullable=False)
    op.create_index(
        "ix_group_expenses_created_by_id", "group_expenses", ["created_by_id"]
    )
    op.create_unique_constraint(
        "uq_group_expenses_idempotency",
        "group_expenses",
        ["group_id", "created_by_id", "idempotency_key"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_group_expenses_idempotency", "group_expenses", type_="unique"
    )
    op.drop_index("ix_group_expenses_created_by_id", table_name="group_expenses")
    op.drop_column("group_expenses", "idempotency_request_hash")
    op.drop_column("group_expenses", "idempotency_key")
    op.drop_column("group_expenses", "created_by_id")
