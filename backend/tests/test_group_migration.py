import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations

MIGRATION_PATH = (
    Path(__file__).resolve().parents[1]
    / "alembic"
    / "versions"
    / "20260810_0005_groups_and_members.py"
)


def _load_migration_module():
    spec = importlib.util.spec_from_file_location(
        "groups_and_members_migration",
        MIGRATION_PATH,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_group_migration_upgrade_and_downgrade() -> None:
    migration = _load_migration_module()
    assert migration.revision == "20260810_0005"
    assert migration.down_revision == "20260806_0004"

    engine = sa.create_engine("sqlite:///:memory:")
    metadata = sa.MetaData()
    sa.Table(
        "users",
        metadata,
        sa.Column("id", sa.Uuid(), primary_key=True),
    )

    with engine.begin() as connection:
        metadata.create_all(connection)
        context = MigrationContext.configure(connection)
        migration.op = Operations(context)

        migration.upgrade()

        inspector = sa.inspect(connection)
        assert {"groups", "group_members"}.issubset(inspector.get_table_names())

        group_columns = {
            column["name"]: column for column in inspector.get_columns("groups")
        }
        assert set(group_columns) == {
            "id",
            "name",
            "description",
            "currency",
            "created_by",
            "created_at",
            "updated_at",
            "archived_at",
        }
        assert group_columns["created_by"]["nullable"] is True

        member_primary_key = inspector.get_pk_constraint("group_members")
        assert member_primary_key["constrained_columns"] == [
            "group_id",
            "user_id",
        ]

        group_foreign_keys = {
            tuple(foreign_key["constrained_columns"]): foreign_key
            for foreign_key in inspector.get_foreign_keys("groups")
        }
        assert group_foreign_keys[("created_by",)]["options"]["ondelete"] == (
            "SET NULL"
        )

        member_foreign_keys = {
            tuple(foreign_key["constrained_columns"]): foreign_key
            for foreign_key in inspector.get_foreign_keys("group_members")
        }
        assert member_foreign_keys[("group_id",)]["options"]["ondelete"] == (
            "CASCADE"
        )
        assert member_foreign_keys[("user_id",)]["options"]["ondelete"] == (
            "CASCADE"
        )

        check_constraints = inspector.get_check_constraints("group_members")
        role_check = next(
            constraint
            for constraint in check_constraints
            if constraint["name"] == "ck_group_members_role"
        )
        assert "owner" in role_check["sqltext"]
        assert "admin" in role_check["sqltext"]
        assert "member" in role_check["sqltext"]

        migration.downgrade()

        remaining_tables = set(sa.inspect(connection).get_table_names())
        assert "groups" not in remaining_tables
        assert "group_members" not in remaining_tables
        assert "users" in remaining_tables

    engine.dispose()
