"""Add activity_log table.

Revision ID: 20260820_0002
Revises: 20260820_0001
Create Date: 2026-08-20
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260820_0002"
down_revision: str | None = "20260820_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "activity_log",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=False),
        sa.Column(
            "type",
            sa.Enum(
                "expense_created",
                "settlement_created",
                "member_joined",
                name="activity_log_type",
                native_enum=False,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("payload_json", sa.JSON(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["group_id"],
            ["groups.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_activity_log_group_created",
        "activity_log",
        ["group_id", "created_at", "id"],
    )
    op.create_index(
        "ix_activity_log_actor_user_id",
        "activity_log",
        ["actor_user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_activity_log_actor_user_id", table_name="activity_log")
    op.drop_index("ix_activity_log_group_created", table_name="activity_log")
    op.drop_table("activity_log")
