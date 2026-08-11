import os
import subprocess
import sys
import uuid
from pathlib import Path

import asyncpg
import pytest
from sqlalchemy.engine import URL, make_url

BACKEND_ROOT = Path(__file__).resolve().parents[1]
EXPECTED_REVISION = "20260810_0005"


def _postgres_test_url() -> URL:
    raw_url = os.getenv("POSTGRES_TEST_DATABASE_URL")
    if not raw_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is required for PostgreSQL tests")
    if not raw_url.startswith("postgresql+asyncpg://"):
        pytest.fail("POSTGRES_TEST_DATABASE_URL must use PostgreSQL with asyncpg")
    return make_url(raw_url)


def _asyncpg_dsn(url: URL) -> str:
    return url.set(drivername="postgresql").render_as_string(hide_password=False)


def _run_alembic(database_url: str, *arguments: str) -> str:
    environment = os.environ.copy()
    environment["DATABASE_URL"] = database_url
    result = subprocess.run(
        [sys.executable, "-m", "alembic", *arguments],
        cwd=BACKEND_ROOT,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )
    output = f"{result.stdout}\n{result.stderr}"
    assert result.returncode == 0, output
    return output


async def _assert_group_schema(database_url: URL) -> None:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        revision = await connection.fetchval("SELECT version_num FROM alembic_version")
        assert revision == EXPECTED_REVISION

        columns = {
            row["column_name"]: row
            for row in await connection.fetch(
                """
                SELECT column_name, data_type, character_maximum_length
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'group_members'
                """
            )
        }
        assert columns["group_id"]["data_type"] == "uuid"
        assert columns["user_id"]["data_type"] == "uuid"
        assert columns["joined_at"]["data_type"] == ("timestamp with time zone")
        assert columns["left_at"]["data_type"] == "timestamp with time zone"
        assert columns["role"]["character_maximum_length"] == 16
    finally:
        await connection.close()


@pytest.mark.asyncio
async def test_group_migration_full_chain_on_postgresql() -> None:
    base_url = _postgres_test_url()
    temporary_database = f"group_migration_{uuid.uuid4().hex}"
    admin_url = base_url.set(database="postgres")
    migration_url = base_url.set(database=temporary_database)
    migration_url_string = migration_url.render_as_string(hide_password=False)

    admin_connection = await asyncpg.connect(_asyncpg_dsn(admin_url))
    try:
        await admin_connection.execute(f'CREATE DATABASE "{temporary_database}"')
        try:
            _run_alembic(migration_url_string, "upgrade", "head")
            current = _run_alembic(migration_url_string, "current")
            assert f"{EXPECTED_REVISION} (head)" in current
            await _assert_group_schema(migration_url)

            _run_alembic(migration_url_string, "downgrade", "base")
            downgraded = await asyncpg.connect(_asyncpg_dsn(migration_url))
            try:
                groups_table = await downgraded.fetchval(
                    "SELECT to_regclass('public.groups')"
                )
                assert groups_table is None
            finally:
                await downgraded.close()

            _run_alembic(migration_url_string, "upgrade", "head")
            current = _run_alembic(migration_url_string, "current")
            assert f"{EXPECTED_REVISION} (head)" in current
            await _assert_group_schema(migration_url)
        finally:
            await admin_connection.execute(
                "SELECT pg_terminate_backend(pid) "
                "FROM pg_stat_activity "
                "WHERE datname = $1 AND pid <> pg_backend_pid()",
                temporary_database,
            )
            await admin_connection.execute(
                f'DROP DATABASE IF EXISTS "{temporary_database}"'
            )
    finally:
        await admin_connection.close()
