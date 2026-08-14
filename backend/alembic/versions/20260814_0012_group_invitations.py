"""Add production group invitations.

Revision ID: 20260814_0012
Revises: 20260813_0011
Create Date: 2026-08-14
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260814_0012"
down_revision: str | None = "20260813_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "group_invitations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("invited_email", sa.String(length=320), nullable=False),
        sa.Column(
            "role",
            sa.String(length=16),
            server_default="member",
            nullable=False,
        ),
        sa.Column("invited_by_user_id", sa.Uuid(), nullable=True),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "expires_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "accepted_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column("accepted_by_user_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "role IN ('admin', 'member')",
            name="ck_group_invitations_role",
        ),
        sa.CheckConstraint(
            "expires_at > created_at",
            name="ck_group_invitations_expiry_after_creation",
        ),
        sa.CheckConstraint(
            "accepted_at IS NOT NULL OR accepted_by_user_id IS NULL",
            name="ck_group_invitations_acceptance_state",
        ),
        sa.ForeignKeyConstraint(
            ["group_id"],
            ["groups.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["invited_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["accepted_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_group_invitations"),
    )
    op.create_index(
        "ix_group_invitations_token_hash",
        "group_invitations",
        ["token_hash"],
        unique=True,
    )
    op.create_index(
        "ix_group_invitations_group_email_created_at",
        "group_invitations",
        ["group_id", "invited_email", "created_at"],
    )
    op.create_index(
        "ix_group_invitations_expires_at",
        "group_invitations",
        ["expires_at"],
    )
    op.create_index(
        "ix_group_invitations_invited_by_user_id",
        "group_invitations",
        ["invited_by_user_id"],
    )
    op.create_index(
        "ix_group_invitations_accepted_by_user_id",
        "group_invitations",
        ["accepted_by_user_id"],
    )


def downgrade() -> None:
    op.drop_table("group_invitations")
