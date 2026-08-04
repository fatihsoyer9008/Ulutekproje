import os
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncConnection, create_async_engine


@pytest_asyncio.fixture
async def postgres_connection() -> AsyncIterator[AsyncConnection]:
    database_url = os.getenv("POSTGRES_TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is required for PostgreSQL tests")
    if not database_url.startswith("postgresql+asyncpg://"):
        pytest.fail("POSTGRES_TEST_DATABASE_URL must use PostgreSQL with asyncpg")

    engine = create_async_engine(database_url)
    try:
        async with engine.connect() as connection:
            transaction = await connection.begin()
            try:
                yield connection
            finally:
                await transaction.rollback()
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_cloud_receipt_migration_is_at_head(
    postgres_connection: AsyncConnection,
) -> None:
    revision = await postgres_connection.scalar(
        text("SELECT version_num FROM alembic_version")
    )
    assert revision == "20260804_0003"

    table_names = set(
        (
            await postgres_connection.execute(
                text(
                    "SELECT table_name FROM information_schema.tables "
                    "WHERE table_schema = 'public' AND table_name IN "
                    "('cloud_receipts', 'cloud_receipt_line_items')"
                )
            )
        ).scalars()
    )
    assert table_names == {"cloud_receipts", "cloud_receipt_line_items"}

    sync_index = await postgres_connection.scalar(
        text(
            "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' "
            "AND tablename = 'cloud_transactions' "
            "AND indexname = 'ix_cloud_transactions_user_updated_id'"
        )
    )
    assert sync_index == "ix_cloud_transactions_user_updated_id"


@pytest.mark.asyncio
async def test_cloud_receipt_constraints_and_cascade(
    postgres_connection: AsyncConnection,
) -> None:
    user_id = uuid.uuid4()
    receipt_id = uuid.uuid4()
    client_record_id = uuid.uuid4()
    line_item_id = uuid.uuid4()
    now = datetime.now(UTC)

    await postgres_connection.execute(
        text(
            "INSERT INTO users "
            "(id, email, is_email_verified, status, auth_version) "
            "VALUES (:id, :email, false, 'active', 1)"
        ),
        {"id": user_id, "email": f"receipt-test-{user_id}@example.com"},
    )
    await postgres_connection.execute(
        text(
            "INSERT INTO cloud_receipts "
            "(id, user_id, client_record_id, installation_id_hash, "
            "total_amount_in_minor, client_created_at, client_updated_at) "
            "VALUES (:id, :user_id, :client_record_id, :installation_id_hash, "
            ":total, :created_at, :updated_at)"
        ),
        {
            "id": receipt_id,
            "user_id": user_id,
            "client_record_id": client_record_id,
            "installation_id_hash": "a" * 64,
            "total": 2550,
            "created_at": now,
            "updated_at": now,
        },
    )
    await postgres_connection.execute(
        text(
            "INSERT INTO cloud_receipt_line_items "
            "(id, receipt_id, client_record_id, position, name, price_in_minor) "
            "VALUES (:id, :receipt_id, :client_record_id, 0, 'Sut', 2550)"
        ),
        {
            "id": line_item_id,
            "receipt_id": receipt_id,
            "client_record_id": uuid.uuid4(),
        },
    )

    with pytest.raises(IntegrityError):
        async with postgres_connection.begin_nested():
            await postgres_connection.execute(
                text(
                    "INSERT INTO cloud_receipts "
                    "(id, user_id, client_record_id, installation_id_hash, "
                    "client_created_at, client_updated_at) "
                    "VALUES (:id, :user_id, :client_record_id, :hash, :now, :now)"
                ),
                {
                    "id": uuid.uuid4(),
                    "user_id": user_id,
                    "client_record_id": client_record_id,
                    "hash": "b" * 64,
                    "now": now,
                },
            )

    with pytest.raises(IntegrityError):
        async with postgres_connection.begin_nested():
            await postgres_connection.execute(
                text(
                    "INSERT INTO cloud_receipt_line_items "
                    "(id, receipt_id, client_record_id, position, name, "
                    "price_in_minor) VALUES "
                    "(:id, :receipt_id, :client_record_id, 1, 'Invalid', -1)"
                ),
                {
                    "id": uuid.uuid4(),
                    "receipt_id": receipt_id,
                    "client_record_id": uuid.uuid4(),
                },
            )

    await postgres_connection.execute(
        text("DELETE FROM cloud_receipts WHERE id = :id"),
        {"id": receipt_id},
    )
    remaining_line_items = await postgres_connection.scalar(
        text("SELECT count(*) FROM cloud_receipt_line_items WHERE id = :line_item_id"),
        {"line_item_id": line_item_id},
    )
    assert remaining_line_items == 0
