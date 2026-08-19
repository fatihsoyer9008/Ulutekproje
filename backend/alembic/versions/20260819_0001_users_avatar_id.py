"""Add avatar_id to users.

Revision ID: 20260819_0001
Revises: 20260818_0016
Create Date: 2026-08-19
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260819_0001"
down_revision: str | None = "20260818_0016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("avatar_id", sa.String(length=32), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "avatar_id")
