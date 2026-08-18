"""Merge group sync change-feed and n8n webhook migration heads.

Revision ID: 20260818_0015
Revises: 20260817_0014, 20260818_0014
Create Date: 2026-08-18
"""

from collections.abc import Sequence

revision: str = "20260818_0015"
down_revision: tuple[str, str] = ("20260817_0014", "20260818_0014")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
