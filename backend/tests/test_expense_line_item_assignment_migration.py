import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations

from app.models import ExpenseLineItemAssignment

MIGRATION_PATH = (
    Path(__file__).resolve().parents[1]
    / "alembic"
    / "versions"
    / "20260811_0007_expense_line_item_assignments.py"
)


def _load_migration_module():
    spec = importlib.util.spec_from_file_location(
        "expense_line_item_assignment_migration",
        MIGRATION_PATH,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_assignment_migration_upgrade_and_downgrade() -> None:
    migration = _load_migration_module()
    assert migration.revision == "20260811_0007"
    assert migration.down_revision == "20260811_0006"

    engine = sa.create_engine("sqlite:///:memory:")
    metadata = sa.MetaData()
    sa.Table(
        "group_expenses",
        metadata,
        sa.Column("id", sa.Uuid(), primary_key=True),
    )
    sa.Table(
        "cloud_receipt_line_items",
        metadata,
        sa.Column("id", sa.Uuid(), primary_key=True),
    )

    with engine.begin() as connection:
        metadata.create_all(connection)
        context = MigrationContext.configure(connection)
        migration.op = Operations(context)

        migration.upgrade()

        inspector = sa.inspect(connection)
        assert "expense_line_item_assignments" in (inspector.get_table_names())

        columns = {
            column["name"]: column
            for column in inspector.get_columns("expense_line_item_assignments")
        }
        assert set(columns) == {
            "expense_id",
            "receipt_line_item_id",
            "user_id",
            "amount_in_minor",
            "quantity_share_milli",
        }
        assert columns["quantity_share_milli"]["nullable"] is True
        assert isinstance(
            ExpenseLineItemAssignment.__table__.c.amount_in_minor.type,
            sa.BigInteger,
        )
        assert isinstance(
            ExpenseLineItemAssignment.__table__.c.quantity_share_milli.type,
            sa.BigInteger,
        )

        primary_key = inspector.get_pk_constraint("expense_line_item_assignments")
        assert primary_key["constrained_columns"] == [
            "expense_id",
            "receipt_line_item_id",
            "user_id",
        ]

        checks = {
            constraint["name"]
            for constraint in inspector.get_check_constraints(
                "expense_line_item_assignments"
            )
        }
        assert {
            "ck_expense_line_item_assignments_amount_nonnegative",
            "ck_expense_line_item_assignments_quantity_positive",
        }.issubset(checks)

        foreign_keys = {
            tuple(foreign_key["constrained_columns"]): foreign_key
            for foreign_key in inspector.get_foreign_keys(
                "expense_line_item_assignments"
            )
        }
        assert foreign_keys[("expense_id",)]["options"]["ondelete"] == "CASCADE"
        assert ("receipt_line_item_id",) not in foreign_keys
        assert ("user_id",) not in foreign_keys

        indexes = {
            index["name"]
            for index in inspector.get_indexes("expense_line_item_assignments")
        }
        assert {
            "ix_expense_line_item_assignments_receipt_line_item_id",
            "ix_expense_line_item_assignments_user_id",
        }.issubset(indexes)

        migration.downgrade()

        assert "expense_line_item_assignments" not in (
            sa.inspect(connection).get_table_names()
        )
        assert {
            "group_expenses",
            "cloud_receipt_line_items",
        }.issubset(sa.inspect(connection).get_table_names())

    engine.dispose()
