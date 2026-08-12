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


async def _insert_expense(
    connection: AsyncConnection,
    *,
    group_id: uuid.UUID,
    receipt_id: uuid.UUID,
    payer_user_id: uuid.UUID,
    now: datetime,
) -> uuid.UUID:
    expense_id = uuid.uuid4()
    await connection.execute(
        text(
            "INSERT INTO group_expenses "
            "(id, group_id, receipt_id, payer_user_id, created_by_id, title, "
            "expense_date, total_amount_in_minor, currency, split_type) "
            "VALUES (:id, :group_id, :receipt_id, :payer_user_id, "
            ":payer_user_id, "
            ":title, :expense_date, 2550, 'TRY', 'itemized')"
        ),
        {
            "id": expense_id,
            "group_id": group_id,
            "receipt_id": receipt_id,
            "payer_user_id": payer_user_id,
            "title": "PostgreSQL ürün atama testi",
            "expense_date": now,
        },
    )
    return expense_id


async def _insert_parent_rows(
    connection: AsyncConnection,
) -> tuple[
    uuid.UUID,
    uuid.UUID,
    uuid.UUID,
    uuid.UUID,
    uuid.UUID,
    datetime,
]:
    user_id = uuid.uuid4()
    group_id = uuid.uuid4()
    receipt_id = uuid.uuid4()
    line_item_id = uuid.uuid4()
    now = datetime.now(UTC)

    await connection.execute(
        text(
            "INSERT INTO users "
            "(id, email, is_email_verified, status, auth_version) "
            "VALUES (:id, :email, false, 'active', 1)"
        ),
        {
            "id": user_id,
            "email": f"assignment-{user_id}@example.com",
        },
    )
    await connection.execute(
        text(
            "INSERT INTO groups (id, name, created_by) "
            "VALUES (:id, :name, :created_by)"
        ),
        {
            "id": group_id,
            "name": "PostgreSQL Atama Grubu",
            "created_by": user_id,
        },
    )
    await connection.execute(
        text(
            "INSERT INTO cloud_receipts "
            "(id, user_id, client_record_id, installation_id_hash, "
            "total_amount_in_minor, client_created_at, client_updated_at) "
            "VALUES (:id, :user_id, :client_record_id, :hash, "
            "2550, :now, :now)"
        ),
        {
            "id": receipt_id,
            "user_id": user_id,
            "client_record_id": uuid.uuid4(),
            "hash": "a" * 64,
            "now": now,
        },
    )
    await connection.execute(
        text(
            "INSERT INTO cloud_receipt_line_items "
            "(id, receipt_id, client_record_id, position, name, "
            "price_in_minor, quantity) "
            "VALUES (:id, :receipt_id, :client_record_id, 0, "
            "'Süt', 2550, 1.000)"
        ),
        {
            "id": line_item_id,
            "receipt_id": receipt_id,
            "client_record_id": uuid.uuid4(),
        },
    )
    expense_id = await _insert_expense(
        connection,
        group_id=group_id,
        receipt_id=receipt_id,
        payer_user_id=user_id,
        now=now,
    )
    return (
        user_id,
        group_id,
        receipt_id,
        line_item_id,
        expense_id,
        now,
    )


@pytest.mark.asyncio
async def test_assignment_migration_is_at_head(
    postgres_connection: AsyncConnection,
) -> None:
    revision = await postgres_connection.scalar(
        text("SELECT version_num FROM alembic_version")
    )
    table_name = await postgres_connection.scalar(
        text("SELECT to_regclass(" "'public.expense_line_item_assignments'" ")")
    )

    assert revision == "20260812_0008"
    assert table_name == "expense_line_item_assignments"


@pytest.mark.asyncio
async def test_assignment_constraints(
    postgres_connection: AsyncConnection,
) -> None:
    (
        user_id,
        _group_id,
        _receipt_id,
        line_item_id,
        expense_id,
        _now,
    ) = await _insert_parent_rows(postgres_connection)

    insert_statement = text(
        "INSERT INTO expense_line_item_assignments "
        "(expense_id, receipt_line_item_id, user_id, "
        "amount_in_minor, quantity_share_milli) "
        "VALUES (:expense_id, :line_item_id, :user_id, "
        ":amount, :quantity)"
    )
    await postgres_connection.execute(
        insert_statement,
        {
            "expense_id": expense_id,
            "line_item_id": line_item_id,
            "user_id": user_id,
            "amount": 2550,
            "quantity": 1000,
        },
    )

    with pytest.raises(IntegrityError):
        async with postgres_connection.begin_nested():
            await postgres_connection.execute(
                insert_statement,
                {
                    "expense_id": expense_id,
                    "line_item_id": line_item_id,
                    "user_id": user_id,
                    "amount": 2550,
                    "quantity": 1000,
                },
            )

    with pytest.raises(IntegrityError):
        async with postgres_connection.begin_nested():
            await postgres_connection.execute(
                insert_statement,
                {
                    "expense_id": expense_id,
                    "line_item_id": line_item_id,
                    "user_id": uuid.uuid4(),
                    "amount": -1,
                    "quantity": 1000,
                },
            )

    with pytest.raises(IntegrityError):
        async with postgres_connection.begin_nested():
            await postgres_connection.execute(
                insert_statement,
                {
                    "expense_id": expense_id,
                    "line_item_id": line_item_id,
                    "user_id": uuid.uuid4(),
                    "amount": 0,
                    "quantity": 0,
                },
            )


@pytest.mark.asyncio
async def test_assignment_cascades_from_expense_and_survives_user_delete(
    postgres_connection: AsyncConnection,
) -> None:
    (
        user_id,
        _group_id,
        _receipt_id,
        line_item_id,
        expense_id,
        _now,
    ) = await _insert_parent_rows(postgres_connection)

    insert_statement = text(
        "INSERT INTO expense_line_item_assignments "
        "(expense_id, receipt_line_item_id, user_id, "
        "amount_in_minor, quantity_share_milli) "
        "VALUES (:expense_id, :line_item_id, :user_id, 2550, 1000)"
    )
    await postgres_connection.execute(
        insert_statement,
        {
            "expense_id": expense_id,
            "line_item_id": line_item_id,
            "user_id": user_id,
        },
    )

    await postgres_connection.execute(
        text("DELETE FROM group_expenses WHERE id = :expense_id"),
        {"expense_id": expense_id},
    )
    remaining_after_expense_delete = await postgres_connection.scalar(
        text(
            "SELECT count(*) "
            "FROM expense_line_item_assignments "
            "WHERE expense_id = :expense_id"
        ),
        {"expense_id": expense_id},
    )
    assert remaining_after_expense_delete == 0

    (
        second_user_id,
        _second_group_id,
        _second_receipt_id,
        second_line_item_id,
        second_expense_id,
        _second_now,
    ) = await _insert_parent_rows(postgres_connection)
    await postgres_connection.execute(
        insert_statement,
        {
            "expense_id": second_expense_id,
            "line_item_id": second_line_item_id,
            "user_id": second_user_id,
        },
    )

    await postgres_connection.execute(
        text("DELETE FROM users WHERE id = :user_id"),
        {"user_id": second_user_id},
    )

    remaining_assignment = await postgres_connection.scalar(
        text(
            "SELECT count(*) "
            "FROM expense_line_item_assignments "
            "WHERE expense_id = :expense_id"
        ),
        {"expense_id": second_expense_id},
    )
    remaining_line_item = await postgres_connection.scalar(
        text(
            "SELECT count(*) "
            "FROM cloud_receipt_line_items "
            "WHERE id = :line_item_id"
        ),
        {"line_item_id": second_line_item_id},
    )
    stored_receipt_id = await postgres_connection.scalar(
        text("SELECT receipt_id " "FROM group_expenses " "WHERE id = :expense_id"),
        {"expense_id": second_expense_id},
    )

    assert remaining_assignment == 1
    assert remaining_line_item == 0
    assert stored_receipt_id is None
