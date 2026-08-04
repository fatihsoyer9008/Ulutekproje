import asyncio
import os
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models.cloud_transaction import CloudTransaction
from app.models.user import User
from app.services.sync_service import SyncService
from app.sync_schemas import PushOperation, TransactionSyncPayload


@pytest.mark.asyncio
async def test_concurrent_create_keeps_newest_client_version() -> None:
    database_url = os.getenv("POSTGRES_TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is required for PostgreSQL tests")
    if not database_url.startswith("postgresql+asyncpg://"):
        pytest.fail("POSTGRES_TEST_DATABASE_URL must use PostgreSQL with asyncpg")

    engine = create_async_engine(database_url)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    user_id: uuid.UUID | None = None
    record_id = uuid.uuid4()
    created_at = datetime(2026, 8, 4, 8, 0, tzinfo=UTC)

    def payload(*, amount: int, updated_at: datetime) -> TransactionSyncPayload:
        return TransactionSyncPayload(
            client_record_id=record_id,
            transaction_type="expense",
            amount_in_minor=amount,
            category="market",
            transaction_date=created_at,
            merchant_name="Concurrency Test",
            source="manual",
            raw_ocr_text=None,
            note=None,
            client_created_at=created_at,
            client_updated_at=updated_at,
        )

    try:
        async with session_factory() as session:
            user = User(email=f"sync-concurrency-{uuid.uuid4()}@example.com")
            session.add(user)
            await session.commit()
            user_id = user.id

        older = payload(amount=1000, updated_at=created_at + timedelta(minutes=1))
        newer = payload(amount=2000, updated_at=created_at + timedelta(minutes=2))

        async def push(candidate: TransactionSyncPayload, operation_id: str) -> None:
            async with session_factory() as session:
                user = await session.get(User, user_id)
                assert user is not None
                await SyncService(session).push(
                    user=user,
                    installation_id="postgres-concurrency-installation",
                    operations=[
                        PushOperation(
                            operation_id=operation_id,
                            action="upsert",
                            client_record_id=record_id,
                            client_updated_at=candidate.client_updated_at,
                            transaction=candidate,
                        )
                    ],
                )

        await asyncio.gather(
            push(older, "concurrent-create-older"),
            push(newer, "concurrent-create-newer"),
        )

        async with session_factory() as session:
            stored = await session.scalar(
                select(CloudTransaction).where(
                    CloudTransaction.user_id == user_id,
                    CloudTransaction.client_record_id == record_id,
                )
            )
        assert stored is not None
        assert stored.amount_in_minor == 2000
        assert stored.client_updated_at == newer.client_updated_at
    finally:
        if user_id is not None:
            async with session_factory() as session:
                user = await session.get(User, user_id)
                if user is not None:
                    await session.delete(user)
                    await session.commit()
        await engine.dispose()
