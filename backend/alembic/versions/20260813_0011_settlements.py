"""Add immutable group settlement records.

Revision ID: 20260813_0011
Revises: 20260812_0010
Create Date: 2026-08-13
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260813_0011"
down_revision: str | None = "20260812_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "settlements",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("from_user_id", sa.Uuid(), nullable=False),
        sa.Column("to_user_id", sa.Uuid(), nullable=False),
        sa.Column("amount_in_minor", sa.BigInteger(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column(
            "settled_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "amount_in_minor > 0",
            name="ck_settlements_amount_positive",
        ),
        sa.CheckConstraint(
            "from_user_id <> to_user_id",
            name="ck_settlements_distinct_users",
        ),
        sa.CheckConstraint(
            "currency = upper(currency) AND length(currency) = 3",
            name="ck_settlements_currency_format",
        ),
        sa.ForeignKeyConstraint(
            ["group_id"],
            ["groups.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_settlements"),
    )
    op.create_index(
        "ix_settlements_group_settled_at_id",
        "settlements",
        ["group_id", "settled_at", "id"],
    )
    op.create_index(
        "ix_settlements_from_user_id",
        "settlements",
        ["from_user_id"],
    )
    op.create_index(
        "ix_settlements_to_user_id",
        "settlements",
        ["to_user_id"],
    )

    op.create_table(
        "settlement_idempotency_records",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=False),
        sa.Column("settlement_id", sa.Uuid(), nullable=True),
        sa.Column(
            "idempotency_key_hash",
            sa.String(length=64),
            nullable=False,
        ),
        sa.Column(
            "request_hash",
            sa.String(length=64),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["group_id"],
            ["groups.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["actor_user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["settlement_id"],
            ["settlements.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "id",
            name="pk_settlement_idempotency_records",
        ),
        sa.UniqueConstraint(
            "group_id",
            "actor_user_id",
            "idempotency_key_hash",
            name="uq_settlement_idempotency_scope_key",
        ),
    )
    op.create_index(
        "ix_settlement_idempotency_actor_user_id",
        "settlement_idempotency_records",
        ["actor_user_id"],
    )
    op.create_index(
        "ix_settlement_idempotency_settlement_id",
        "settlement_idempotency_records",
        ["settlement_id"],
    )


def downgrade() -> None:
    op.drop_table("settlement_idempotency_records")
    op.drop_table("settlements")
