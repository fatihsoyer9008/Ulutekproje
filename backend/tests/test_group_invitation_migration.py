import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations

from app.models import GroupInvitation

MIGRATION_PATH = (
    Path(__file__).resolve().parents[1]
    / "alembic"
    / "versions"
    / "20260814_0012_group_invitations.py"
)


def _load_migration_module():
    spec = importlib.util.spec_from_file_location(
        "group_invitation_migration",
        MIGRATION_PATH,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_group_invitation_migration_upgrade_and_downgrade() -> None:
    migration = _load_migration_module()
    assert migration.revision == "20260814_0012"
    assert migration.down_revision == "20260813_0011"

    engine = sa.create_engine("sqlite:///:memory:")
    metadata = sa.MetaData()
    sa.Table("users", metadata, sa.Column("id", sa.Uuid(), primary_key=True))
    sa.Table("groups", metadata, sa.Column("id", sa.Uuid(), primary_key=True))

    with engine.begin() as connection:
        metadata.create_all(connection)
        context = MigrationContext.configure(connection)
        migration.op = Operations(context)
        migration.upgrade()

        inspector = sa.inspect(connection)
        assert "group_invitations" in inspector.get_table_names()
        columns = {
            column["name"]: column
            for column in inspector.get_columns("group_invitations")
        }
        assert set(columns) == {
            "id",
            "group_id",
            "invited_email",
            "role",
            "invited_by_user_id",
            "token_hash",
            "expires_at",
            "accepted_at",
            "accepted_by_user_id",
            "created_at",
        }
        assert columns["role"]["type"].length == 16
        assert GroupInvitation.__table__.c.role.type.length == 16

        indexes = {
            index["name"]: index for index in inspector.get_indexes("group_invitations")
        }
        assert indexes["ix_group_invitations_token_hash"]["unique"] == 1
        assert indexes["ix_group_invitations_group_email_created_at"][
            "column_names"
        ] == ["group_id", "invited_email", "created_at"]

        foreign_keys = {
            tuple(item["constrained_columns"]): item
            for item in inspector.get_foreign_keys("group_invitations")
        }
        assert foreign_keys[("group_id",)]["options"]["ondelete"] == "CASCADE"
        assert (
            foreign_keys[("invited_by_user_id",)]["options"]["ondelete"]
            == "SET NULL"
        )
        assert (
            foreign_keys[("accepted_by_user_id",)]["options"]["ondelete"]
            == "SET NULL"
        )

        migration.downgrade()
        assert "group_invitations" not in sa.inspect(connection).get_table_names()

    engine.dispose()
