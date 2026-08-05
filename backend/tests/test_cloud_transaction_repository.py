import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.cloud_transaction import CloudTransaction
from app.models.user import User
from app.repositories.cloud_transactions import CloudTransactionRepository


@pytest_asyncio.fixture
async def repository_context() -> AsyncIterator[
    tuple[AsyncSession, CloudTransactionRepository, User, User]
]:
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async with session_factory() as session:
        first_user = User(email="repository-first@example.com")
        second_user = User(email="repository-second@example.com")
        session.add_all([first_user, second_user])
        await session.commit()

        yield (
            session,
            CloudTransactionRepository(session),
            first_user,
            second_user,
        )

    await engine.dispose()


def _transaction_values(
    *,
    user_id: uuid.UUID,
    client_record_id: uuid.UUID,
    amount_in_minor: int = 2550,
    client_updated_at: datetime | None = None,
) -> dict[str, object]:
    now = datetime(2026, 8, 5, 9, 0, tzinfo=UTC)
    return {
        "id": uuid.uuid4(),
        "user_id": user_id,
        "client_record_id": client_record_id,
        "installation_id_hash": "a" * 64,
        "transaction_type": "expense",
        "amount_in_minor": amount_in_minor,
        "category": "market",
        "transaction_date": now,
        "merchant_name": "Repository Market",
        "source": "manual",
        "raw_ocr_text": None,
        "note": None,
        "client_created_at": now,
        "client_updated_at": client_updated_at or now,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
    }


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


@pytest.mark.asyncio
async def test_repository_insert_is_idempotent_per_user(
    repository_context,
) -> None:
    session, repository, first_user, second_user = repository_context
    client_record_id = uuid.uuid4()

    first = await repository.try_insert(
        values=_transaction_values(
            user_id=first_user.id,
            client_record_id=client_record_id,
        )
    )
    duplicate = await repository.try_insert(
        values=_transaction_values(
            user_id=first_user.id,
            client_record_id=client_record_id,
        )
    )
    other_user = await repository.try_insert(
        values=_transaction_values(
            user_id=second_user.id,
            client_record_id=client_record_id,
        )
    )
    await session.commit()

    assert first is not None
    assert duplicate is None
    assert other_user is not None
    stored = (await session.scalars(select(CloudTransaction))).all()
    assert len(stored) == 2


@pytest.mark.asyncio
async def test_database_rejects_duplicate_user_client_record_pair(
    repository_context,
) -> None:
    session, _, first_user, _ = repository_context
    client_record_id = uuid.uuid4()
    session.add_all(
        [
            CloudTransaction(
                **_transaction_values(
                    user_id=first_user.id,
                    client_record_id=client_record_id,
                )
            ),
            CloudTransaction(
                **_transaction_values(
                    user_id=first_user.id,
                    client_record_id=client_record_id,
                )
            ),
        ]
    )

    with pytest.raises(IntegrityError):
        await session.commit()
    await session.rollback()


@pytest.mark.asyncio
async def test_repository_only_applies_newer_updates(
    repository_context,
) -> None:
    session, repository, first_user, _ = repository_context
    client_record_id = uuid.uuid4()
    initial_time = datetime(2026, 8, 5, 9, 0, tzinfo=UTC)
    created = await repository.try_insert(
        values=_transaction_values(
            user_id=first_user.id,
            client_record_id=client_record_id,
            amount_in_minor=1000,
            client_updated_at=initial_time,
        )
    )
    assert created is not None

    stale = await repository.update_if_newer(
        user_id=first_user.id,
        client_record_id=client_record_id,
        client_updated_at=initial_time - timedelta(seconds=1),
        values={
            "amount_in_minor": 500,
            "client_updated_at": initial_time - timedelta(seconds=1),
        },
    )
    newer_time = initial_time + timedelta(seconds=1)
    updated = await repository.update_if_newer(
        user_id=first_user.id,
        client_record_id=client_record_id,
        client_updated_at=newer_time,
        values={
            "amount_in_minor": 2000,
            "client_updated_at": newer_time,
        },
    )
    await session.commit()

    assert stale is None
    assert updated is not None
    assert updated.amount_in_minor == 2000
    assert _as_utc(updated.client_updated_at) == newer_time


@pytest.mark.asyncio
async def test_repository_soft_delete_keeps_tombstone(
    repository_context,
) -> None:
    session, repository, first_user, _ = repository_context
    client_record_id = uuid.uuid4()
    initial_time = datetime(2026, 8, 5, 9, 0, tzinfo=UTC)
    created = await repository.try_insert(
        values=_transaction_values(
            user_id=first_user.id,
            client_record_id=client_record_id,
            client_updated_at=initial_time,
        )
    )
    assert created is not None

    deleted_at = initial_time + timedelta(minutes=1)
    deleted = await repository.delete_if_newer(
        user_id=first_user.id,
        client_record_id=client_record_id,
        client_updated_at=deleted_at,
        deleted_at=deleted_at,
    )
    await session.commit()

    assert deleted is not None
    assert deleted.deleted_at is not None
    assert _as_utc(deleted.deleted_at) == deleted_at
    assert await repository.get_for_user(
        user_id=first_user.id,
        client_record_id=client_record_id,
    ) is not None
