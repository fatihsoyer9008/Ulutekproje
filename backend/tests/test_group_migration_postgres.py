import os
import subprocess
import sys
import uuid
from pathlib import Path

import asyncpg
import pytest
from sqlalchemy.engine import URL, make_url

BACKEND_ROOT = Path(__file__).resolve().parents[1]
EXPECTED_REVISION = "20260811_0007"


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

        columns = {row["column_name"]: row for row in await connection.fetch("""
                SELECT column_name, data_type, character_maximum_length
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'group_members'
                """)}
        assert columns["group_id"]["data_type"] == "uuid"
        assert columns["user_id"]["data_type"] == "uuid"
        assert columns["joined_at"]["data_type"] == ("timestamp with time zone")
        assert columns["left_at"]["data_type"] == "timestamp with time zone"
        assert columns["role"]["character_maximum_length"] == 16
    finally:
        await connection.close()


async def _assert_group_expense_schema(database_url: URL) -> None:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        revision = await connection.fetchval("SELECT version_num FROM alembic_version")
        assert revision == EXPECTED_REVISION

        column_rows = await connection.fetch("""
            SELECT
                table_name,
                column_name,
                data_type,
                character_maximum_length,
                is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name IN ('group_expenses', 'expense_shares')
            """)
        columns = {(row["table_name"], row["column_name"]): row for row in column_rows}

        assert columns[("group_expenses", "id")]["data_type"] == "uuid"
        assert columns[("group_expenses", "group_id")]["data_type"] == "uuid"
        assert columns[("group_expenses", "receipt_id")]["data_type"] == "uuid"
        assert columns[("group_expenses", "payer_user_id")]["data_type"] == ("uuid")
        assert (
            columns[("group_expenses", "total_amount_in_minor")]["data_type"]
            == "bigint"
        )
        assert columns[("group_expenses", "expense_date")]["data_type"] == (
            "timestamp with time zone"
        )
        assert columns[("group_expenses", "deleted_at")]["data_type"] == (
            "timestamp with time zone"
        )
        assert columns[("group_expenses", "currency")]["character_maximum_length"] == 3
        assert (
            columns[("group_expenses", "split_type")]["character_maximum_length"] == 16
        )
        assert columns[("group_expenses", "payer_user_id")]["is_nullable"] == "NO"

        assert columns[("expense_shares", "expense_id")]["data_type"] == "uuid"
        assert columns[("expense_shares", "user_id")]["data_type"] == "uuid"
        assert columns[("expense_shares", "amount_in_minor")]["data_type"] == "bigint"
        assert columns[("expense_shares", "settled_at")]["data_type"] == (
            "timestamp with time zone"
        )
        assert columns[("expense_shares", "status")]["character_maximum_length"] == 24
        assert columns[("expense_shares", "user_id")]["is_nullable"] == "NO"

        primary_key_rows = await connection.fetch("""
            SELECT kcu.column_name
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
              ON kcu.constraint_catalog = tc.constraint_catalog
             AND kcu.constraint_schema = tc.constraint_schema
             AND kcu.constraint_name = tc.constraint_name
            WHERE tc.table_schema = 'public'
              AND tc.table_name = 'expense_shares'
              AND tc.constraint_type = 'PRIMARY KEY'
            ORDER BY kcu.ordinal_position
            """)
        assert [row["column_name"] for row in primary_key_rows] == [
            "expense_id",
            "user_id",
        ]

        check_names = {row["conname"] for row in await connection.fetch("""
                SELECT conname
                FROM pg_constraint
                WHERE contype = 'c'
                  AND conrelid IN (
                    'public.group_expenses'::regclass,
                    'public.expense_shares'::regclass
                  )
                """)}
        assert {
            "ck_group_expenses_total_nonnegative",
            "ck_group_expenses_split_type",
            "ck_expense_shares_amount_nonnegative",
            "ck_expense_shares_status",
        }.issubset(check_names)

        foreign_key_rows = await connection.fetch("""
            SELECT
                kcu.table_name,
                kcu.column_name,
                rc.delete_rule
            FROM information_schema.referential_constraints AS rc
            JOIN information_schema.key_column_usage AS kcu
              ON kcu.constraint_catalog = rc.constraint_catalog
             AND kcu.constraint_schema = rc.constraint_schema
             AND kcu.constraint_name = rc.constraint_name
            WHERE kcu.table_schema = 'public'
              AND kcu.table_name IN ('group_expenses', 'expense_shares')
            """)
        foreign_keys = {
            (row["table_name"], row["column_name"]): row["delete_rule"]
            for row in foreign_key_rows
        }

        assert foreign_keys[("group_expenses", "group_id")] == "CASCADE"
        assert foreign_keys[("group_expenses", "receipt_id")] == "SET NULL"
        assert foreign_keys[("expense_shares", "expense_id")] == "CASCADE"
        assert ("group_expenses", "payer_user_id") not in foreign_keys
        assert ("expense_shares", "user_id") not in foreign_keys

        index_names = {row["indexname"] for row in await connection.fetch("""
                SELECT indexname
                FROM pg_indexes
                WHERE schemaname = 'public'
                  AND tablename IN ('group_expenses', 'expense_shares')
                """)}
        assert {
            "ix_group_expenses_group_deleted_date",
            "ix_group_expenses_receipt_id",
            "ix_group_expenses_payer_user_id",
            "ix_expense_shares_user_id",
        }.issubset(index_names)
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
            await _assert_group_expense_schema(migration_url)
            _run_alembic(migration_url_string, "downgrade", "base")
            downgraded = await asyncpg.connect(_asyncpg_dsn(migration_url))
            try:
                groups_table = await downgraded.fetchval(
                    "SELECT to_regclass('public.groups')"
                )
                expenses_table = await downgraded.fetchval(
                    "SELECT to_regclass('public.group_expenses')"
                )
                shares_table = await downgraded.fetchval(
                    "SELECT to_regclass('public.expense_shares')"
                )
                assignments_table = await downgraded.fetchval(
                    "SELECT to_regclass(" "'public.expense_line_item_assignments'" ")"
                )
                assert groups_table is None
                assert expenses_table is None
                assert shares_table is None
                assert assignments_table is None
            finally:
                await downgraded.close()

            _run_alembic(migration_url_string, "upgrade", "head")
            current = _run_alembic(migration_url_string, "current")
            assert f"{EXPECTED_REVISION} (head)" in current
            await _assert_group_schema(migration_url)
            await _assert_group_expense_schema(migration_url)
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
