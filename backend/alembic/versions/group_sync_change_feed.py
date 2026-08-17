"""Add durable group sync pull change feed.

Revision ID: 20260817_0014
Revises: 20260817_0013
Create Date: 2026-08-17
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260817_0014"
down_revision: str | None = "20260817_0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "group_sync_changes",
        sa.Column("sequence_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=False),
        sa.Column("client_record_id", sa.Uuid(), nullable=False),
        sa.Column("operation_type", sa.String(length=32), nullable=False),
        sa.Column("operation_data", sa.JSON(), nullable=False),
        sa.Column("server_updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["group_id"], ["groups.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["actor_user_id"], ["users.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("sequence_id", name="pk_group_sync_changes"),
        sa.UniqueConstraint(
            "actor_user_id",
            "client_record_id",
            name="uq_group_sync_changes_actor_record",
        ),
    )
    op.create_index(
        "ix_group_sync_changes_group_sequence",
        "group_sync_changes",
        ["group_id", "sequence_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_group_sync_changes_group_sequence", table_name="group_sync_changes"
    )
    op.drop_table("group_sync_changes")
