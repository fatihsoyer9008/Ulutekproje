import os
import subprocess
import sys
import uuid
from pathlib import Path

import asyncpg
import pytest
from sqlalchemy.engine import URL, make_url

BACKEND_ROOT = Path(__file__).resolve().parents[1]
EXPECTED_REVISION = "20260818_0014"
PRE_GROUP_REVISION = "20260806_0004"
PRE_EXPENSE_REVISION = "20260810_0005"
PRE_ASSIGNMENT_REVISION = "20260811_0006"

GROUP_TABLES = (
    "groups",
    "group_members",
    "group_expenses",
    "expense_shares",
    "expense_line_item_assignments",
    "expense_extra_amounts",
    "expense_extra_amount_shares",
    "group_expense_idempotency_records",
    "settlements",
    "settlement_idempotency_records",
    "group_invitations",
)

LEGACY_TABLE_KEYS = (
    ("users", "id", "user_id"),
    ("oauth_accounts", "id", "oauth_account_id"),
    ("refresh_sessions", "id", "refresh_session_id"),
    ("one_time_tokens", "id", "one_time_token_id"),
    ("cloud_transactions", "id", "transaction_id"),
    ("cloud_receipts", "id", "receipt_id"),
    ("cloud_receipt_line_items", "id", "line_item_id"),
    ("sync_claim_requests", "id", "sync_claim_request_id"),
)

PRE_EXPENSE_TABLE_KEYS = (
    ("groups", "id", "group_id"),
    ("group_members", "group_id", "group_id"),
)

PRE_ASSIGNMENT_TABLE_KEYS = (
    ("groups", "id", "group_id"),
    ("group_members", "group_id", "group_id"),
    ("group_expenses", "id", "expense_id"),
    ("expense_shares", "expense_id", "expense_id"),
)


def _postgres_test_url() -> URL:
    raw_url = os.getenv("POSTGRES_TEST_DATABASE_URL")
    if not raw_url:
        if os.getenv("REQUIRE_POSTGRES_TESTS", "").lower() in {
            "1",
            "true",
            "yes",
        }:
            pytest.fail(
                "POSTGRES_TEST_DATABASE_URL is required when "
                "REQUIRE_POSTGRES_TESTS is enabled"
            )
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


async def _seed_legacy_data(
    database_url: URL,
) -> dict[str, uuid.UUID]:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        identifiers = {
            "user_id": uuid.uuid4(),
            "oauth_account_id": uuid.uuid4(),
            "refresh_session_id": uuid.uuid4(),
            "refresh_family_id": uuid.uuid4(),
            "one_time_token_id": uuid.uuid4(),
            "transaction_id": uuid.uuid4(),
            "transaction_client_id": uuid.uuid4(),
            "receipt_id": uuid.uuid4(),
            "receipt_client_id": uuid.uuid4(),
            "line_item_id": uuid.uuid4(),
            "line_item_client_id": uuid.uuid4(),
            "sync_claim_request_id": uuid.uuid4(),
        }

        await connection.execute(
            """
            INSERT INTO users (
                id,
                email,
                password_hash,
                display_name,
                is_email_verified,
                status,
                auth_version
            )
            VALUES ($1, $2, $3, $4, true, 'active', 1)
            """,
            identifiers["user_id"],
            f"migration-regression-{identifiers['user_id']}@example.com",
            "legacy-password-hash",
            "Legacy Migration User",
        )
        await connection.execute(
            """
            INSERT INTO oauth_accounts (
                id, user_id, provider, provider_subject, provider_email
            )
            VALUES ($1, $2, 'google', $3, $4)
            """,
            identifiers["oauth_account_id"],
            identifiers["user_id"],
            f"provider-{identifiers['oauth_account_id']}",
            f"oauth-{identifiers['user_id']}@example.com",
        )
        await connection.execute(
            """
            INSERT INTO refresh_sessions (
                id, user_id, family_id, token_hash, expires_at,
                device_name, user_agent
            )
            VALUES (
                $1, $2, $3, $4,
                TIMESTAMPTZ '2026-09-10 12:30:00+03',
                'Migration Device', 'migration-regression-agent'
            )
            """,
            identifiers["refresh_session_id"],
            identifiers["user_id"],
            identifiers["refresh_family_id"],
            uuid.uuid4().hex + uuid.uuid4().hex,
        )
        await connection.execute(
            """
            INSERT INTO one_time_tokens (
                id, user_id, purpose, token_hash, expires_at
            )
            VALUES (
                $1, $2, 'verify_email', $3,
                TIMESTAMPTZ '2026-08-11 12:30:00+03'
            )
            """,
            identifiers["one_time_token_id"],
            identifiers["user_id"],
            uuid.uuid4().hex + uuid.uuid4().hex,
        )
        await connection.execute(
            """
            INSERT INTO cloud_transactions (
                id,
                user_id,
                client_record_id,
                installation_id_hash,
                transaction_type,
                amount_in_minor,
                category,
                transaction_date,
                merchant_name,
                source,
                raw_ocr_text,
                note,
                client_created_at,
                client_updated_at
            )
            VALUES (
                $1,
                $2,
                $3,
                $4,
                'expense',
                34990,
                'market',
                TIMESTAMPTZ '2026-08-10 12:30:00+03',
                'Legacy Market',
                'manual',
                'LEGACY TRANSACTION OCR',
                'migration-regression',
                TIMESTAMPTZ '2026-08-10 12:30:00+03',
                TIMESTAMPTZ '2026-08-10 12:35:00+03'
            )
            """,
            identifiers["transaction_id"],
            identifiers["user_id"],
            identifiers["transaction_client_id"],
            "t" * 64,
        )
        await connection.execute(
            """
            INSERT INTO cloud_receipts (
                id,
                user_id,
                client_record_id,
                installation_id_hash,
                merchant_name,
                total_amount_in_minor,
                currency,
                receipt_date,
                category,
                normalized_ocr_text,
                raw_ocr_text,
                is_parse_successful,
                confidence_score,
                client_created_at,
                client_updated_at
            )
            VALUES (
                $1,
                $2,
                $3,
                $4,
                'Legacy Receipt Market',
                34990,
                'TRY',
                TIMESTAMPTZ '2026-08-10 12:30:00+03',
                'market',
                'LEGACY NORMALIZED OCR',
                'LEGACY RAW OCR',
                true,
                0.9875,
                TIMESTAMPTZ '2026-08-10 12:30:00+03',
                TIMESTAMPTZ '2026-08-10 12:35:00+03'
            )
            """,
            identifiers["receipt_id"],
            identifiers["user_id"],
            identifiers["receipt_client_id"],
            "r" * 64,
        )
        await connection.execute(
            """
            INSERT INTO cloud_receipt_line_items (
                id,
                receipt_id,
                client_record_id,
                position,
                name,
                price_in_minor,
                quantity,
                unit_price_in_minor,
                category
            )
            VALUES (
                $1,
                $2,
                $3,
                0,
                'Legacy Ürün',
                34990,
                1.000,
                34990,
                'market'
            )
            """,
            identifiers["line_item_id"],
            identifiers["receipt_id"],
            identifiers["line_item_client_id"],
        )
        await connection.execute(
            """
            INSERT INTO sync_claim_requests (
                id, user_id, idempotency_key_hash, request_hash, response_json
            )
            VALUES ($1, $2, $3, $4, $5::json)
            """,
            identifiers["sync_claim_request_id"],
            identifiers["user_id"],
            uuid.uuid4().hex + uuid.uuid4().hex,
            uuid.uuid4().hex + uuid.uuid4().hex,
            '{"status":"accepted"}',
        )

        return identifiers
    finally:
        await connection.close()


async def _legacy_snapshot(
    database_url: URL,
    identifiers: dict[str, uuid.UUID],
) -> dict[str, object]:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        snapshot: dict[str, object] = {}

        for table_name, id_column, identifier_key in LEGACY_TABLE_KEYS:
            row = await connection.fetchrow(
                f'SELECT * FROM "{table_name}" WHERE "{id_column}" = $1',
                identifiers[identifier_key],
            )
            count = await connection.fetchval(f'SELECT count(*) FROM "{table_name}"')

            assert row is not None
            snapshot[table_name] = {
                "count": count,
                "row": dict(row),
            }

        return snapshot
    finally:
        await connection.close()


async def _seed_pre_assignment_group_data(
    database_url: URL,
    identifiers: dict[str, uuid.UUID],
) -> None:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        identifiers["group_id"] = uuid.uuid4()
        identifiers["expense_id"] = uuid.uuid4()

        await connection.execute(
            """
            INSERT INTO groups (id, name, description, currency, created_by)
            VALUES ($1, 'Existing Group', 'Created before assignment migration',
                    'TRY', $2)
            """,
            identifiers["group_id"],
            identifiers["user_id"],
        )
        await connection.execute(
            """
            INSERT INTO group_members (group_id, user_id, role)
            VALUES ($1, $2, 'owner')
            """,
            identifiers["group_id"],
            identifiers["user_id"],
        )
        await connection.execute(
            """
            INSERT INTO group_expenses (
                id,
                group_id,
                receipt_id,
                payer_user_id,
                title,
                note,
                expense_date,
                total_amount_in_minor,
                currency,
                split_type
            )
            VALUES (
                $1, $2, $3, $4, 'Existing Expense',
                'Must survive the assignment migration',
                TIMESTAMPTZ '2026-08-10 12:30:00+03',
                34990, 'TRY', 'itemized'
            )
            """,
            identifiers["expense_id"],
            identifiers["group_id"],
            identifiers["receipt_id"],
            identifiers["user_id"],
        )
        await connection.execute(
            """
            INSERT INTO expense_shares (
                expense_id, user_id, amount_in_minor, status
            )
            VALUES ($1, $2, 34990, 'open')
            """,
            identifiers["expense_id"],
            identifiers["user_id"],
        )
    finally:
        await connection.close()


async def _seed_pre_expense_group_data(
    database_url: URL,
    identifiers: dict[str, uuid.UUID],
) -> None:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        identifiers["group_id"] = uuid.uuid4()
        await connection.execute(
            """
            INSERT INTO groups (id, name, description, currency, created_by)
            VALUES (
                $1, 'Existing Group', 'Created before expense migration',
                'TRY', $2
            )
            """,
            identifiers["group_id"],
            identifiers["user_id"],
        )
        await connection.execute(
            """
            INSERT INTO group_members (group_id, user_id, role)
            VALUES ($1, $2, 'owner')
            """,
            identifiers["group_id"],
            identifiers["user_id"],
        )
    finally:
        await connection.close()


async def _pre_expense_snapshot(
    database_url: URL,
    identifiers: dict[str, uuid.UUID],
) -> dict[str, object]:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        snapshot: dict[str, object] = {}
        for table_name, id_column, identifier_key in PRE_EXPENSE_TABLE_KEYS:
            rows = await connection.fetch(
                f'SELECT * FROM "{table_name}" WHERE "{id_column}" = $1',
                identifiers[identifier_key],
            )
            count = await connection.fetchval(f'SELECT count(*) FROM "{table_name}"')
            assert rows
            normalized_rows = [dict(row) for row in rows]
            if table_name == "group_expenses":
                for row in normalized_rows:
                    row.pop("created_by_id", None)
                    row.pop("idempotency_key", None)
                    row.pop("idempotency_request_hash", None)

                    if "created_by" in row:
                        assert row.pop("created_by") is None
            snapshot[table_name] = {
                "count": count,
                "rows": normalized_rows,
            }
        return snapshot
    finally:
        await connection.close()


async def _pre_assignment_snapshot(
    database_url: URL,
    identifiers: dict[str, uuid.UUID],
) -> dict[str, object]:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        snapshot: dict[str, object] = {}
        for table_name, id_column, identifier_key in PRE_ASSIGNMENT_TABLE_KEYS:
            rows = await connection.fetch(
                f'SELECT * FROM "{table_name}" WHERE "{id_column}" = $1',
                identifiers[identifier_key],
            )
            count = await connection.fetchval(f'SELECT count(*) FROM "{table_name}"')
            assert rows

            normalized_rows = [dict(row) for row in rows]
            if table_name == "group_expenses":
                for row in normalized_rows:
                    row.pop("created_by_id", None)
                    row.pop("idempotency_key", None)
                    row.pop("idempotency_request_hash", None)

                    if "created_by" in row:
                        assert row.pop("created_by") is None

            snapshot[table_name] = {
                "count": count,
                "rows": normalized_rows,
            }
        return snapshot
    finally:
        await connection.close()


async def _assert_group_relations_and_indexes(
    database_url: URL,
) -> None:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        foreign_key_rows = await connection.fetch(
            """
            SELECT
                tc.table_name,
                kcu.column_name,
                ccu.table_name AS referenced_table,
                ccu.column_name AS referenced_column,
                rc.delete_rule
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
              ON kcu.constraint_catalog = tc.constraint_catalog
             AND kcu.constraint_schema = tc.constraint_schema
             AND kcu.constraint_name = tc.constraint_name
            JOIN information_schema.referential_constraints AS rc
              ON rc.constraint_catalog = tc.constraint_catalog
             AND rc.constraint_schema = tc.constraint_schema
             AND rc.constraint_name = tc.constraint_name
            JOIN information_schema.constraint_column_usage AS ccu
              ON ccu.constraint_catalog = rc.unique_constraint_catalog
             AND ccu.constraint_schema = rc.unique_constraint_schema
             AND ccu.constraint_name = rc.unique_constraint_name
            WHERE tc.table_schema = 'public'
              AND tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_name = ANY($1::text[])
            """,
            list(GROUP_TABLES),
        )
        foreign_keys = {
            (row["table_name"], row["column_name"]): (
                row["referenced_table"],
                row["referenced_column"],
                row["delete_rule"],
            )
            for row in foreign_key_rows
        }

        assert foreign_keys[("groups", "created_by")] == (
            "users",
            "id",
            "SET NULL",
        )
        assert foreign_keys[("group_members", "group_id")] == (
            "groups",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("group_members", "user_id")] == (
            "users",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("group_expenses", "group_id")] == (
            "groups",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("group_expenses", "receipt_id")] == (
            "cloud_receipts",
            "id",
            "SET NULL",
        )
        assert foreign_keys[("expense_shares", "expense_id")] == (
            "group_expenses",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("expense_line_item_assignments", "expense_id")] == (
            "group_expenses",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("group_expense_idempotency_records", "group_id")] == (
            "groups",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("group_expense_idempotency_records", "actor_user_id")] == (
            "users",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("group_expense_idempotency_records", "expense_id")] == (
            "group_expenses",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("settlements", "group_id")] == (
            "groups",
            "id",
            "CASCADE",
        )
        assert (
            "settlements",
            "from_user_id",
        ) not in foreign_keys
        assert (
            "settlements",
            "to_user_id",
        ) not in foreign_keys
        assert foreign_keys[("settlement_idempotency_records", "group_id")] == (
            "groups",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("settlement_idempotency_records", "actor_user_id")] == (
            "users",
            "id",
            "CASCADE",
        )
        assert foreign_keys[("settlement_idempotency_records", "settlement_id")] == (
            "settlements",
            "id",
            "CASCADE",
        )
        assert ("group_expenses", "payer_user_id") not in foreign_keys
        assert ("expense_shares", "user_id") not in foreign_keys
        assert (
            "expense_line_item_assignments",
            "receipt_line_item_id",
        ) not in foreign_keys
        assert (
            "expense_line_item_assignments",
            "user_id",
        ) not in foreign_keys

        index_rows = await connection.fetch(
            """
            SELECT
                index_class.relname AS index_name,
                index_meta.indisunique AS is_unique,
                ARRAY(
                    SELECT pg_get_indexdef(
                        index_meta.indexrelid,
                        position,
                        true
                    )
                    FROM generate_series(
                        1,
                        index_meta.indnkeyatts
                    ) AS position
                    ORDER BY position
                ) AS columns,
                pg_get_expr(
                    index_meta.indpred,
                    index_meta.indrelid
                ) AS predicate
            FROM pg_index AS index_meta
            JOIN pg_class AS table_class
              ON table_class.oid = index_meta.indrelid
            JOIN pg_class AS index_class
              ON index_class.oid = index_meta.indexrelid
            JOIN pg_namespace AS namespace
              ON namespace.oid = table_class.relnamespace
            WHERE namespace.nspname = 'public'
              AND table_class.relname = ANY($1::text[])
            """,
            list(GROUP_TABLES),
        )
        indexes = {
            row["index_name"]: {
                "columns": list(row["columns"]),
                "unique": row["is_unique"],
                "predicate": row["predicate"],
            }
            for row in index_rows
        }
        expected_indexes = {
            "ix_groups_created_by": ["created_by"],
            "ix_groups_archived_at": ["archived_at"],
            "ix_group_members_user_id": ["user_id"],
            "ix_group_members_group_left_at": ["group_id", "left_at"],
            "ix_group_expenses_group_deleted_date": [
                "group_id",
                "deleted_at",
                "expense_date",
                "id",
            ],
            "ix_group_expenses_receipt_id": ["receipt_id"],
            "ix_group_expenses_payer_user_id": ["payer_user_id"],
            "ix_expense_shares_user_id": ["user_id"],
            "ix_expense_line_item_assignments_receipt_line_item_id": [
                "receipt_line_item_id"
            ],
            "ix_expense_line_item_assignments_user_id": ["user_id"],
            "ix_group_expense_idempotency_actor_user_id": ["actor_user_id"],
            "ix_group_expense_idempotency_expense_id": ["expense_id"],
            "ix_settlements_group_settled_at_id": [
                "group_id",
                "settled_at",
                "id",
            ],
            "ix_settlements_from_user_id": ["from_user_id"],
            "ix_settlements_to_user_id": ["to_user_id"],
            "ix_settlement_idempotency_actor_user_id": ["actor_user_id"],
            "ix_settlement_idempotency_settlement_id": ["settlement_id"],
        }
        for index_name, expected_columns in expected_indexes.items():
            assert indexes[index_name] == {
                "columns": expected_columns,
                "unique": False,
                "predicate": None,
            }

        assert indexes["uq_group_expense_idempotency_scope_key"] == {
            "columns": [
                "group_id",
                "actor_user_id",
                "idempotency_key_hash",
            ],
            "unique": True,
            "predicate": None,
        }

        assert indexes["uq_settlement_idempotency_scope_key"] == {
            "columns": [
                "group_id",
                "actor_user_id",
                "idempotency_key_hash",
            ],
            "unique": True,
            "predicate": None,
        }
    finally:
        await connection.close()


async def _assert_constraint_violation(
    connection: asyncpg.Connection,
    error_type: type[Exception],
    constraint_name: str,
    query: str,
    *arguments: object,
) -> None:
    transaction = connection.transaction()
    await transaction.start()
    try:
        with pytest.raises(error_type) as exception:
            await connection.execute(query, *arguments)

        assert getattr(exception.value, "constraint_name", None) == constraint_name
    finally:
        await transaction.rollback()


async def _assert_constraints_and_group_cascade(
    database_url: URL,
    identifiers: dict[str, uuid.UUID],
) -> None:
    connection = await asyncpg.connect(_asyncpg_dsn(database_url))
    try:
        group_id = uuid.uuid4()
        invalid_role_group_id = uuid.uuid4()
        expense_id = uuid.uuid4()
        user_id = identifiers["user_id"]
        receipt_id = identifiers["receipt_id"]
        line_item_id = identifiers["line_item_id"]

        await connection.execute(
            """
            INSERT INTO groups (id, name, created_by)
            VALUES ($1, 'Migration Regression Group', $2)
            """,
            group_id,
            user_id,
        )
        await connection.execute(
            """
            INSERT INTO groups (id, name, created_by)
            VALUES ($1, 'Invalid Role Test Group', $2)
            """,
            invalid_role_group_id,
            user_id,
        )
        await connection.execute(
            """
            INSERT INTO group_members (group_id, user_id, role)
            VALUES ($1, $2, 'owner')
            """,
            group_id,
            user_id,
        )
        await connection.execute(
            """
            INSERT INTO group_expenses (
                id,
                group_id,
                receipt_id,
                payer_user_id,
                created_by_id,
                title,
                expense_date,
                total_amount_in_minor,
                currency,
                split_type
            )
            VALUES (
                $1,
                $2,
                $3,
                $4,
                $4,
                'Migration Regression Expense',
                TIMESTAMPTZ '2026-08-10 12:30:00+03',
                34990,
                'TRY',
                'itemized'
            )
            """,
            expense_id,
            group_id,
            receipt_id,
            user_id,
        )
        await connection.execute(
            """
            INSERT INTO expense_shares (
                expense_id,
                user_id,
                amount_in_minor,
                status
            )
            VALUES ($1, $2, 34990, 'open')
            """,
            expense_id,
            user_id,
        )
        await connection.execute(
            """
            INSERT INTO expense_line_item_assignments (
                expense_id,
                receipt_line_item_id,
                user_id,
                amount_in_minor,
                quantity_share_milli
            )
            VALUES ($1, $2, $3, 34990, 1000)
            """,
            expense_id,
            line_item_id,
            user_id,
        )

        await _assert_constraint_violation(
            connection,
            asyncpg.UniqueViolationError,
            "pk_group_members",
            """
            INSERT INTO group_members (group_id, user_id, role)
            VALUES ($1, $2, 'member')
            """,
            group_id,
            user_id,
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.CheckViolationError,
            "ck_group_members_role",
            """
            INSERT INTO group_members (group_id, user_id, role)
            VALUES ($1, $2, 'invalid-role')
            """,
            invalid_role_group_id,
            user_id,
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.CheckViolationError,
            "ck_group_expenses_total_nonnegative",
            """
            INSERT INTO group_expenses (
                id,
                group_id,
                payer_user_id,
                created_by_id,
                title,
                expense_date,
                total_amount_in_minor,
                currency,
                split_type
            )
            VALUES (
                $1,
                $2,
                $3,
                $3,
                'Negative Total',
                CURRENT_TIMESTAMP,
                -1,
                'TRY',
                'equal'
            )
            """,
            uuid.uuid4(),
            group_id,
            user_id,
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.CheckViolationError,
            "ck_group_expenses_split_type",
            """
            INSERT INTO group_expenses (
                id,
                group_id,
                payer_user_id,
                created_by_id,
                title,
                expense_date,
                total_amount_in_minor,
                currency,
                split_type
            )
            VALUES (
                $1,
                $2,
                $3,
                $3,
                'Invalid Split Type',
                CURRENT_TIMESTAMP,
                100,
                'TRY',
                'invalid'
            )
            """,
            uuid.uuid4(),
            group_id,
            user_id,
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.CheckViolationError,
            "ck_expense_shares_amount_nonnegative",
            """
            INSERT INTO expense_shares (
                expense_id,
                user_id,
                amount_in_minor,
                status
            )
            VALUES ($1, $2, -1, 'open')
            """,
            expense_id,
            uuid.uuid4(),
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.CheckViolationError,
            "ck_expense_shares_status",
            """
            INSERT INTO expense_shares (
                expense_id,
                user_id,
                amount_in_minor,
                status
            )
            VALUES ($1, $2, 0, 'invalid')
            """,
            expense_id,
            uuid.uuid4(),
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.UniqueViolationError,
            "pk_expense_shares",
            """
            INSERT INTO expense_shares (
                expense_id,
                user_id,
                amount_in_minor,
                status
            )
            VALUES ($1, $2, 34990, 'open')
            """,
            expense_id,
            user_id,
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.CheckViolationError,
            "ck_expense_line_item_assignments_amount_nonnegative",
            """
            INSERT INTO expense_line_item_assignments (
                expense_id,
                receipt_line_item_id,
                user_id,
                amount_in_minor,
                quantity_share_milli
            )
            VALUES ($1, $2, $3, -1, 1000)
            """,
            expense_id,
            line_item_id,
            uuid.uuid4(),
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.UniqueViolationError,
            "pk_expense_line_item_assignments",
            """
            INSERT INTO expense_line_item_assignments (
                expense_id,
                receipt_line_item_id,
                user_id,
                amount_in_minor,
                quantity_share_milli
            )
            VALUES ($1, $2, $3, 34990, 1000)
            """,
            expense_id,
            line_item_id,
            user_id,
        )
        await _assert_constraint_violation(
            connection,
            asyncpg.CheckViolationError,
            "ck_expense_line_item_assignments_quantity_positive",
            """
            INSERT INTO expense_line_item_assignments (
                expense_id,
                receipt_line_item_id,
                user_id,
                amount_in_minor,
                quantity_share_milli
            )
            VALUES ($1, $2, $3, 0, 0)
            """,
            expense_id,
            line_item_id,
            uuid.uuid4(),
        )

        await connection.execute(
            "DELETE FROM groups WHERE id = $1",
            group_id,
        )
        remaining = await connection.fetchrow(
            """
            SELECT
                (
                    SELECT count(*)
                    FROM groups
                    WHERE id = $1
                ) AS groups,
                (
                    SELECT count(*)
                    FROM group_members
                    WHERE group_id = $1
                ) AS members,
                (
                    SELECT count(*)
                    FROM group_expenses
                    WHERE group_id = $1
                ) AS expenses,
                (
                    SELECT count(*)
                    FROM expense_shares
                    WHERE expense_id = $2
                ) AS shares,
                (
                    SELECT count(*)
                    FROM expense_line_item_assignments
                    WHERE expense_id = $2
                ) AS assignments
            """,
            group_id,
            expense_id,
        )

        assert remaining is not None
        assert dict(remaining) == {
            "groups": 0,
            "members": 0,
            "expenses": 0,
            "shares": 0,
            "assignments": 0,
        }

        await connection.execute(
            "DELETE FROM groups WHERE id = $1",
            invalid_role_group_id,
        )
    finally:
        await connection.close()


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
              AND table_name IN (
                  'group_expenses',
                  'expense_shares',
                  'group_expense_idempotency_records'
              )
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
        assert columns[("group_expenses", "created_by")]["data_type"] == "uuid"
        assert columns[("group_expenses", "created_by")]["is_nullable"] == "YES"

        assert (
            columns[("group_expense_idempotency_records", "group_id")]["data_type"]
            == "uuid"
        )
        assert (
            columns[("group_expense_idempotency_records", "group_id")]["is_nullable"]
            == "NO"
        )

        assert (
            columns[("group_expense_idempotency_records", "actor_user_id")]["data_type"]
            == "uuid"
        )
        assert (
            columns[("group_expense_idempotency_records", "actor_user_id")][
                "is_nullable"
            ]
            == "NO"
        )

        assert (
            columns[("group_expense_idempotency_records", "expense_id")]["data_type"]
            == "uuid"
        )
        assert (
            columns[("group_expense_idempotency_records", "expense_id")]["is_nullable"]
            == "YES"
        )

        assert (
            columns[("group_expense_idempotency_records", "idempotency_key_hash")][
                "character_maximum_length"
            ]
            == 64
        )
        assert (
            columns[("group_expense_idempotency_records", "request_hash")][
                "character_maximum_length"
            ]
            == 64
        )
        assert (
            columns[("group_expense_idempotency_records", "created_at")]["data_type"]
            == "timestamp with time zone"
        )

        assert (
            "group_expense_idempotency_records",
            "response_json",
        ) not in columns

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
              AND kcu.table_name IN (
                  'group_expenses',
                  'expense_shares',
                  'group_expense_idempotency_records'
              )
            """)
        foreign_keys = {
            (row["table_name"], row["column_name"]): row["delete_rule"]
            for row in foreign_key_rows
        }

        assert foreign_keys[("group_expenses", "group_id")] == "CASCADE"
        assert foreign_keys[("group_expenses", "receipt_id")] == "SET NULL"
        assert foreign_keys[("expense_shares", "expense_id")] == "CASCADE"
        assert (
            foreign_keys[("group_expense_idempotency_records", "group_id")] == "CASCADE"
        )
        assert (
            foreign_keys[("group_expense_idempotency_records", "actor_user_id")]
            == "CASCADE"
        )
        assert (
            foreign_keys[("group_expense_idempotency_records", "expense_id")]
            == "CASCADE"
        )
        assert ("group_expenses", "payer_user_id") not in foreign_keys
        assert ("expense_shares", "user_id") not in foreign_keys

        index_names = {row["indexname"] for row in await connection.fetch("""
                SELECT indexname
                FROM pg_indexes
                WHERE schemaname = 'public'
                  AND tablename IN (
                      'group_expenses',
                      'expense_shares',
                      'group_expense_idempotency_records'
                  )
                """)}
        assert {
            "ix_group_expenses_group_deleted_date",
            "ix_group_expenses_receipt_id",
            "ix_group_expenses_payer_user_id",
            "ix_expense_shares_user_id",
            "ix_group_expense_idempotency_actor_user_id",
            "ix_group_expense_idempotency_expense_id",
            "uq_group_expense_idempotency_scope_key",
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


@pytest.mark.asyncio
async def test_group_migrations_preserve_legacy_data_on_postgresql() -> None:
    base_url = _postgres_test_url()
    temporary_database = f"group_data_loss_{uuid.uuid4().hex}"
    admin_url = base_url.set(database="postgres")
    migration_url = base_url.set(database=temporary_database)
    migration_url_string = migration_url.render_as_string(hide_password=False)

    admin_connection = await asyncpg.connect(_asyncpg_dsn(admin_url))
    try:
        await admin_connection.execute(f'CREATE DATABASE "{temporary_database}"')
        try:
            _run_alembic(
                migration_url_string,
                "upgrade",
                PRE_GROUP_REVISION,
            )
            identifiers = await _seed_legacy_data(migration_url)
            before_upgrade = await _legacy_snapshot(
                migration_url,
                identifiers,
            )

            _run_alembic(migration_url_string, "upgrade", "head")
            current = _run_alembic(migration_url_string, "current")

            assert f"{EXPECTED_REVISION} (head)" in current
            await _assert_group_schema(migration_url)
            await _assert_group_expense_schema(migration_url)
            await _assert_group_relations_and_indexes(migration_url)

            after_upgrade = await _legacy_snapshot(
                migration_url,
                identifiers,
            )
            assert after_upgrade == before_upgrade

            await _assert_constraints_and_group_cascade(
                migration_url,
                identifiers,
            )
            after_cascade = await _legacy_snapshot(
                migration_url,
                identifiers,
            )
            assert after_cascade == before_upgrade

            _run_alembic(
                migration_url_string,
                "downgrade",
                PRE_GROUP_REVISION,
            )
            after_downgrade = await _legacy_snapshot(
                migration_url,
                identifiers,
            )
            assert after_downgrade == before_upgrade

            downgraded_connection = await asyncpg.connect(_asyncpg_dsn(migration_url))
            try:
                remaining_group_tables = await downgraded_connection.fetch(
                    """
                    SELECT table_name
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                      AND table_name = ANY($1::text[])
                    """,
                    list(GROUP_TABLES),
                )
                assert {row["table_name"] for row in remaining_group_tables} == set()
            finally:
                await downgraded_connection.close()

            _run_alembic(migration_url_string, "upgrade", "head")
            current = _run_alembic(migration_url_string, "current")

            assert f"{EXPECTED_REVISION} (head)" in current
            await _assert_group_schema(migration_url)
            await _assert_group_expense_schema(migration_url)
            await _assert_group_relations_and_indexes(migration_url)

            after_second_upgrade = await _legacy_snapshot(
                migration_url,
                identifiers,
            )
            assert after_second_upgrade == before_upgrade
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


@pytest.mark.asyncio
async def test_expense_migration_preserves_existing_group_data() -> None:
    """Upgrade/downgrade 0006 without losing rows created at revision 0005."""
    base_url = _postgres_test_url()
    temporary_database = f"group_expense_upgrade_{uuid.uuid4().hex}"
    admin_url = base_url.set(database="postgres")
    migration_url = base_url.set(database=temporary_database)
    migration_url_string = migration_url.render_as_string(hide_password=False)

    admin_connection = await asyncpg.connect(_asyncpg_dsn(admin_url))
    try:
        await admin_connection.execute(f'CREATE DATABASE "{temporary_database}"')
        try:
            _run_alembic(
                migration_url_string,
                "upgrade",
                PRE_EXPENSE_REVISION,
            )
            identifiers = await _seed_legacy_data(migration_url)
            await _seed_pre_expense_group_data(migration_url, identifiers)

            legacy_before = await _legacy_snapshot(migration_url, identifiers)
            group_before = await _pre_expense_snapshot(
                migration_url,
                identifiers,
            )

            _run_alembic(
                migration_url_string,
                "upgrade",
                PRE_ASSIGNMENT_REVISION,
            )
            current = _run_alembic(migration_url_string, "current")
            assert PRE_ASSIGNMENT_REVISION in current
            assert await _legacy_snapshot(migration_url, identifiers) == legacy_before
            assert (
                await _pre_expense_snapshot(migration_url, identifiers) == group_before
            )

            connection = await asyncpg.connect(_asyncpg_dsn(migration_url))
            try:
                assert (
                    await connection.fetchval(
                        "SELECT to_regclass('public.group_expenses')"
                    )
                    == "group_expenses"
                )
                assert (
                    await connection.fetchval(
                        "SELECT to_regclass('public.expense_shares')"
                    )
                    == "expense_shares"
                )
                await connection.execute(
                    """
                    INSERT INTO group_expenses (
                        id,
                        group_id,
                        receipt_id,
                        payer_user_id,
                        title,
                        expense_date,
                        total_amount_in_minor,
                        currency,
                        split_type
                    )
                    VALUES (
                        $1, $2, $3, $4, 'Expense migration check',
                        TIMESTAMPTZ '2026-08-11 10:00:00+03',
                        34990, 'TRY', 'equal'
                    )
                    """,
                    uuid.uuid4(),
                    identifiers["group_id"],
                    identifiers["receipt_id"],
                    identifiers["user_id"],
                )
            finally:
                await connection.close()

            _run_alembic(
                migration_url_string,
                "downgrade",
                PRE_EXPENSE_REVISION,
            )
            assert await _legacy_snapshot(migration_url, identifiers) == legacy_before
            assert (
                await _pre_expense_snapshot(migration_url, identifiers) == group_before
            )

            connection = await asyncpg.connect(_asyncpg_dsn(migration_url))
            try:
                assert (
                    await connection.fetchval(
                        "SELECT to_regclass('public.group_expenses')"
                    )
                    is None
                )
                assert (
                    await connection.fetchval(
                        "SELECT to_regclass('public.expense_shares')"
                    )
                    is None
                )
            finally:
                await connection.close()

            _run_alembic(
                migration_url_string,
                "upgrade",
                PRE_ASSIGNMENT_REVISION,
            )
            assert await _legacy_snapshot(migration_url, identifiers) == legacy_before
            assert (
                await _pre_expense_snapshot(migration_url, identifiers) == group_before
            )
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


@pytest.mark.asyncio
async def test_assignment_migration_preserves_existing_group_data() -> None:
    """Upgrade/downgrade 0007-0010 without losing rows created at revision 0006."""
    base_url = _postgres_test_url()
    temporary_database = f"group_assignment_upgrade_{uuid.uuid4().hex}"
    admin_url = base_url.set(database="postgres")
    migration_url = base_url.set(database=temporary_database)
    migration_url_string = migration_url.render_as_string(hide_password=False)

    admin_connection = await asyncpg.connect(_asyncpg_dsn(admin_url))
    try:
        await admin_connection.execute(f'CREATE DATABASE "{temporary_database}"')
        try:
            _run_alembic(
                migration_url_string,
                "upgrade",
                PRE_ASSIGNMENT_REVISION,
            )
            identifiers = await _seed_legacy_data(migration_url)
            await _seed_pre_assignment_group_data(migration_url, identifiers)

            legacy_before = await _legacy_snapshot(migration_url, identifiers)
            group_before = await _pre_assignment_snapshot(
                migration_url,
                identifiers,
            )

            _run_alembic(migration_url_string, "upgrade", "head")
            current = _run_alembic(migration_url_string, "current")
            assert f"{EXPECTED_REVISION} (head)" in current
            assert await _legacy_snapshot(migration_url, identifiers) == legacy_before
            assert (
                await _pre_assignment_snapshot(migration_url, identifiers)
                == group_before
            )

            connection = await asyncpg.connect(_asyncpg_dsn(migration_url))
            try:
                assignment_table = await connection.fetchval(
                    "SELECT to_regclass('public.expense_line_item_assignments')"
                )
                assert assignment_table == "expense_line_item_assignments"
                await connection.execute(
                    """
                    INSERT INTO expense_line_item_assignments (
                        expense_id,
                        receipt_line_item_id,
                        user_id,
                        amount_in_minor,
                        quantity_share_milli
                    )
                    VALUES ($1, $2, $3, 34990, 1000)
                    """,
                    identifiers["expense_id"],
                    identifiers["line_item_id"],
                    identifiers["user_id"],
                )
            finally:
                await connection.close()

            _run_alembic(
                migration_url_string,
                "downgrade",
                PRE_ASSIGNMENT_REVISION,
            )
            connection = await asyncpg.connect(_asyncpg_dsn(migration_url))
            try:
                assignment_table = await connection.fetchval(
                    "SELECT to_regclass('public.expense_line_item_assignments')"
                )
                assert assignment_table is None
            finally:
                await connection.close()

            assert await _legacy_snapshot(migration_url, identifiers) == legacy_before
            assert (
                await _pre_assignment_snapshot(migration_url, identifiers)
                == group_before
            )

            _run_alembic(migration_url_string, "upgrade", "head")
            assert await _legacy_snapshot(migration_url, identifiers) == legacy_before
            assert (
                await _pre_assignment_snapshot(migration_url, identifiers)
                == group_before
            )
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
