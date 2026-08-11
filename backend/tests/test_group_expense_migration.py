import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations

from app.models import ExpenseShare, GroupExpense

MIGRATION_PATH = (
    Path(__file__).resolve().parents[1]
    / "alembic"
    / "versions"
    / "20260811_0006_group_expenses_and_shares.py"
)


def _load_migration_module():
    spec = importlib.util.spec_from_file_location(
        "group_expenses_and_shares_migration",
        MIGRATION_PATH,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_group_expense_migration_upgrade_and_downgrade() -> None:
    migration = _load_migration_module()
    assert migration.revision == "20260811_0006"
    assert migration.down_revision == "20260810_0005"

    engine = sa.create_engine("sqlite:///:memory:")
    metadata = sa.MetaData()
    sa.Table(
        "users",
        metadata,
        sa.Column("id", sa.Uuid(), primary_key=True),
    )
    sa.Table(
        "groups",
        metadata,
        sa.Column("id", sa.Uuid(), primary_key=True),
    )
    sa.Table(
        "cloud_receipts",
        metadata,
        sa.Column("id", sa.Uuid(), primary_key=True),
    )

    with engine.begin() as connection:
        metadata.create_all(connection)
        context = MigrationContext.configure(connection)
        migration.op = Operations(context)

        migration.upgrade()

        inspector = sa.inspect(connection)
        assert {"group_expenses", "expense_shares"}.issubset(
            inspector.get_table_names()
        )

        expense_columns = {
            column["name"]: column for column in inspector.get_columns("group_expenses")
        }
        assert set(expense_columns) == {
            "id",
            "group_id",
            "receipt_id",
            "payer_user_id",
            "title",
            "note",
            "expense_date",
            "total_amount_in_minor",
            "currency",
            "split_type",
            "created_at",
            "updated_at",
            "deleted_at",
        }
        assert isinstance(
            GroupExpense.__table__.c.total_amount_in_minor.type,
            sa.BigInteger,
        )
        assert expense_columns["receipt_id"]["nullable"] is True
        assert expense_columns["deleted_at"]["nullable"] is True

        share_columns = {
            column["name"]: column for column in inspector.get_columns("expense_shares")
        }
        assert set(share_columns) == {
            "expense_id",
            "user_id",
            "amount_in_minor",
            "status",
            "settled_at",
        }
        assert isinstance(
            ExpenseShare.__table__.c.amount_in_minor.type,
            sa.BigInteger,
        )

        share_primary_key = inspector.get_pk_constraint("expense_shares")
        assert share_primary_key["constrained_columns"] == [
            "expense_id",
            "user_id",
        ]

        expense_checks = {
            constraint["name"]: constraint["sqltext"]
            for constraint in inspector.get_check_constraints("group_expenses")
        }
        assert "ck_group_expenses_total_nonnegative" in expense_checks
        assert "ck_group_expenses_split_type" in expense_checks

        share_checks = {
            constraint["name"]: constraint["sqltext"]
            for constraint in inspector.get_check_constraints("expense_shares")
        }
        assert "ck_expense_shares_amount_nonnegative" in share_checks
        assert "ck_expense_shares_status" in share_checks

        expense_foreign_keys = {
            tuple(foreign_key["constrained_columns"]): foreign_key
            for foreign_key in inspector.get_foreign_keys("group_expenses")
        }
        assert expense_foreign_keys[("group_id",)]["options"]["ondelete"] == ("CASCADE")
        assert expense_foreign_keys[("receipt_id",)]["options"]["ondelete"] == (
            "SET NULL"
        )
        assert ("payer_user_id",) not in expense_foreign_keys

        share_foreign_keys = {
            tuple(foreign_key["constrained_columns"]): foreign_key
            for foreign_key in inspector.get_foreign_keys("expense_shares")
        }
        assert share_foreign_keys[("expense_id",)]["options"]["ondelete"] == ("CASCADE")
        assert ("user_id",) not in share_foreign_keys

        expense_indexes = {
            index["name"] for index in inspector.get_indexes("group_expenses")
        }
        assert {
            "ix_group_expenses_group_deleted_date",
            "ix_group_expenses_receipt_id",
            "ix_group_expenses_payer_user_id",
        }.issubset(expense_indexes)

        share_indexes = {
            index["name"] for index in inspector.get_indexes("expense_shares")
        }
        assert "ix_expense_shares_user_id" in share_indexes

        migration.downgrade()

        remaining_tables = set(sa.inspect(connection).get_table_names())
        assert "group_expenses" not in remaining_tables
        assert "expense_shares" not in remaining_tables
        assert {"users", "groups", "cloud_receipts"}.issubset(remaining_tables)

    engine.dispose()
