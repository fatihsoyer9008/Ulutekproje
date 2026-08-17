import importlib.util
from pathlib import Path

from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, inspect

MIGRATION_PATH = (
    Path(__file__).resolve().parents[1]
    / "alembic"
    / "versions"
    / "group_sync_change_feed.py"
)


def _load_migration_module():
    spec = importlib.util.spec_from_file_location(
        "group_sync_change_feed_migration",
        MIGRATION_PATH,
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_group_sync_change_feed_upgrade_and_downgrade() -> None:
    migration = _load_migration_module()
    assert migration.revision == "20260817_0014"
    assert migration.down_revision == "20260817_0013"

    engine = create_engine("sqlite:///:memory:")
    with engine.begin() as connection:
        context = MigrationContext.configure(connection)
        migration.op = Operations(context)

        migration.upgrade()

        inspector = inspect(connection)
        columns = {
            column["name"]: column
            for column in inspector.get_columns("group_sync_changes")
        }
        assert set(columns) == {
            "sequence_id",
            "group_id",
            "actor_user_id",
            "client_record_id",
            "operation_type",
            "operation_data",
            "server_updated_at",
            "created_at",
        }
        assert columns["sequence_id"]["primary_key"] == 1
        assert columns["operation_data"]["nullable"] is False

        indexes = {
            index["name"]: index for index in inspector.get_indexes("group_sync_changes")
        }
        assert indexes["ix_group_sync_changes_group_sequence"][
            "column_names"
        ] == ["group_id", "sequence_id"]

        unique_constraints = {
            constraint["name"]: constraint
            for constraint in inspector.get_unique_constraints("group_sync_changes")
        }
        assert unique_constraints["uq_group_sync_changes_actor_record"][
            "column_names"
        ] == ["actor_user_id", "client_record_id"]

        migration.downgrade()
        assert "group_sync_changes" not in inspect(connection).get_table_names()
