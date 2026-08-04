"""Add claim idempotency storage and sync pull index.

Revision ID: 20260804_0003
Revises: 20260803_0002
Create Date: 2026-08-04
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260804_0003"
down_revision: str | None = "20260803_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "sync_claim_requests",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("idempotency_key_hash", sa.String(length=64), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("response_json", sa.JSON(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "idempotency_key_hash",
            name="uq_sync_claim_request_user_key",
        ),
    )
    op.create_index(
        "ix_cloud_transactions_user_updated_id",
        "cloud_transactions",
        ["user_id", "updated_at", "id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_cloud_transactions_user_updated_id",
        table_name="cloud_transactions",
    )
    op.drop_table("sync_claim_requests")
