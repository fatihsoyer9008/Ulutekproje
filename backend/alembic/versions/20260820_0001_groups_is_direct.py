"""Add is_direct to groups.

Revision ID: 20260820_0001
Revises: 20260819_0001
Create Date: 2026-08-20
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260820_0001"
down_revision: str | None = "20260819_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "groups",
        sa.Column(
            "is_direct",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
    )
    op.create_index("ix_groups_is_direct", "groups", ["is_direct"])


def downgrade() -> None:
    op.drop_index("ix_groups_is_direct", table_name="groups")
    op.drop_column("groups", "is_direct")
