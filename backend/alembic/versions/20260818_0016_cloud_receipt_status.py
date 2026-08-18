"""Add status (draft/approved/rejected) to cloud_receipts.

Revision ID: 20260818_0016
Revises: 20260818_0015
Create Date: 2026-08-18
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260818_0016"
down_revision: str | None = "20260818_0015"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "cloud_receipts",
        sa.Column(
            "status",
            sa.Enum(
                "draft",
                "approved",
                "rejected",
                name="cloud_receipt_status",
                native_enum=False,
            ),
            server_default="approved",
            nullable=False,
        ),
    )
    op.create_index(
        "ix_cloud_receipts_user_status",
        "cloud_receipts",
        ["user_id", "status"],
    )


def downgrade() -> None:
    op.drop_index("ix_cloud_receipts_user_status", table_name="cloud_receipts")
    op.drop_column("cloud_receipts", "status")
