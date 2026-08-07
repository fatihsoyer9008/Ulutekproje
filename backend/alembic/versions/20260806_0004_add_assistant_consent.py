"""Add AI assistant consent fields.

Revision ID: 20260806_0004
Revises: 20260804_0003
Create Date: 2026-08-06
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260806_0004"
down_revision: str | None = "20260804_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "assistant_consent_version",
            sa.String(length=64),
            nullable=True,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "assistant_consent_granted_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "assistant_consent_revoked_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "assistant_consent_revoked_at")
    op.drop_column("users", "assistant_consent_granted_at")
    op.drop_column("users", "assistant_consent_version")
