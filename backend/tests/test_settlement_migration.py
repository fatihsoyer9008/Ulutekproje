import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations

from app.models import Settlement

MIGRATION_PATH = (
    Path(__file__).resolve().parents[1]
    / "alembic"
    / "versions"
    / "20260813_0011_settlements.py"
)


def _load_migration_module():
    spec = importlib.util.spec_from_file_location(
        "settlements_migration",
        MIGRATION_PATH,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_settlement_migration_upgrade_and_downgrade() -> None:
    migration = _load_migration_module()
    assert migration.revision == "20260813_0011"
    assert migration.down_revision == "20260812_0010"

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

    with engine.begin() as connection:
        metadata.create_all(connection)
        context = MigrationContext.configure(connection)
        migration.op = Operations(context)

        migration.upgrade()

        inspector = sa.inspect(connection)
        assert {
            "settlements",
            "settlement_idempotency_records",
        }.issubset(inspector.get_table_names())

        columns = {
            column["name"]: column for column in inspector.get_columns("settlements")
        }
        assert set(columns) == {
            "id",
            "group_id",
            "from_user_id",
            "to_user_id",
            "amount_in_minor",
            "currency",
            "settled_at",
            "note",
            "created_at",
        }
        assert isinstance(
            Settlement.__table__.c.amount_in_minor.type,
            sa.BigInteger,
        )

        checks = {
            constraint["name"]
            for constraint in inspector.get_check_constraints("settlements")
        }
        assert {
            "ck_settlements_amount_positive",
            "ck_settlements_distinct_users",
            "ck_settlements_currency_format",
        }.issubset(checks)

        foreign_keys = {
            tuple(foreign_key["constrained_columns"]): foreign_key
            for foreign_key in inspector.get_foreign_keys("settlements")
        }
        assert foreign_keys[("group_id",)]["options"]["ondelete"] == ("CASCADE")
        assert ("from_user_id",) not in foreign_keys
        assert ("to_user_id",) not in foreign_keys

        indexes = {index["name"] for index in inspector.get_indexes("settlements")}
        assert {
            "ix_settlements_group_settled_at_id",
            "ix_settlements_from_user_id",
            "ix_settlements_to_user_id",
        }.issubset(indexes)

        unique_constraints = {
            constraint["name"]
            for constraint in inspector.get_unique_constraints(
                "settlement_idempotency_records"
            )
        }
        assert "uq_settlement_idempotency_scope_key" in (unique_constraints)

        migration.downgrade()

        remaining_tables = set(sa.inspect(connection).get_table_names())
        assert "settlements" not in remaining_tables
        assert "settlement_idempotency_records" not in (remaining_tables)
        assert {"users", "groups"}.issubset(remaining_tables)

    engine.dispose()
