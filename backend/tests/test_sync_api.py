import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_current_user
from app.core.database import Base, get_db_session
from app.main import app
from app.models.cloud_transaction import CloudTransaction
from app.models.user import User

INSTALLATION_ID = "installation-sync-test-1234"


def transaction_payload(
    *,
    client_record_id: uuid.UUID | None = None,
    amount_in_minor: int = 2550,
    created_at: datetime | None = None,
    updated_at: datetime | None = None,
) -> dict[str, object]:
    created = created_at or datetime(2026, 8, 4, 8, 0, tzinfo=UTC)
    updated = updated_at or created
    return {
        "client_record_id": str(client_record_id or uuid.uuid4()),
        "transaction_type": "expense",
        "amount_in_minor": amount_in_minor,
        "category": "market",
        "transaction_date": "2026-08-04T07:30:00+00:00",
        "merchant_name": "Test Market",
        "source": "manual",
        "raw_ocr_text": None,
        "note": "weekly shopping",
        "client_created_at": created.isoformat(),
        "client_updated_at": updated.isoformat(),
    }


@pytest_asyncio.fixture
async def sync_context():
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
        first_user = User(email="first@example.com")
        second_user = User(email="second@example.com")
        session.add_all([first_user, second_user])
        await session.commit()

    current_user = {"value": first_user}

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_current_user() -> User:
        return current_user["value"]

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_current_user

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport,
        base_url="http://test",
    ) as client:
        yield client, session_factory, current_user, first_user, second_user

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_sync_endpoints_require_authentication() -> None:
    app.dependency_overrides.clear()
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        response = await client.get("/api/v1/sync/pull")

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_claim_is_idempotent_and_hashes_installation(sync_context) -> None:
    client, session_factory, _, first_user, _ = sync_context
    payload = transaction_payload()
    request = {
        "installation_id": INSTALLATION_ID,
        "transactions": [payload],
    }

    first = await client.post("/api/v1/sync/claim", json=request)
    second = await client.post("/api/v1/sync/claim", json=request)

    assert first.status_code == 200
    assert first.json()["owner_key"] == f"user:{first_user.id}"
    assert first.json()["results"][0]["status"] == "created"
    assert second.status_code == 200
    assert second.json()["results"][0]["status"] == "unchanged"

    async with session_factory() as session:
        stored = (await session.scalars(select(CloudTransaction))).all()
    assert len(stored) == 1
    assert stored[0].installation_id_hash != INSTALLATION_ID
    assert len(stored[0].installation_id_hash) == 64


@pytest.mark.asyncio
async def test_push_handles_update_conflict_and_idempotent_delete(
    sync_context,
) -> None:
    client, _, _, _, _ = sync_context
    record_id = uuid.uuid4()
    created_at = datetime(2026, 8, 4, 8, 0, tzinfo=UTC)
    original = transaction_payload(
        client_record_id=record_id,
        created_at=created_at,
        updated_at=created_at,
    )
    claim = await client.post(
        "/api/v1/sync/claim",
        json={"installation_id": INSTALLATION_ID, "transactions": [original]},
    )
    assert claim.status_code == 200

    newer_at = created_at + timedelta(minutes=1)
    newer = transaction_payload(
        client_record_id=record_id,
        amount_in_minor=3000,
        created_at=created_at,
        updated_at=newer_at,
    )
    update_operation = {
        "operation_id": "task-update-0001",
        "action": "upsert",
        "client_record_id": str(record_id),
        "client_updated_at": newer_at.isoformat(),
        "transaction": newer,
    }

    updated = await client.post(
        "/api/v1/sync/push",
        json={"installation_id": INSTALLATION_ID, "operations": [update_operation]},
    )
    repeated = await client.post(
        "/api/v1/sync/push",
        json={"installation_id": INSTALLATION_ID, "operations": [update_operation]},
    )
    stale_operation = {
        "operation_id": "task-stale-0001",
        "action": "upsert",
        "client_record_id": str(record_id),
        "client_updated_at": created_at.isoformat(),
        "transaction": original,
    }
    stale = await client.post(
        "/api/v1/sync/push",
        json={"installation_id": INSTALLATION_ID, "operations": [stale_operation]},
    )

    assert updated.json()["results"][0]["status"] == "updated"
    assert repeated.json()["results"][0]["status"] == "unchanged"
    assert stale.json()["results"][0]["status"] == "conflict"

    deleted_at = newer_at + timedelta(minutes=1)
    delete_operation = {
        "operation_id": "task-delete-0001",
        "action": "delete",
        "client_record_id": str(record_id),
        "client_updated_at": deleted_at.isoformat(),
    }
    deleted = await client.post(
        "/api/v1/sync/push",
        json={"installation_id": INSTALLATION_ID, "operations": [delete_operation]},
    )
    repeated_delete = await client.post(
        "/api/v1/sync/push",
        json={"installation_id": INSTALLATION_ID, "operations": [delete_operation]},
    )

    assert deleted.json()["results"][0]["status"] == "deleted"
    assert repeated_delete.json()["results"][0]["status"] == "unchanged"


@pytest.mark.asyncio
async def test_pull_is_cursor_paginated_and_includes_tombstones(
    sync_context,
) -> None:
    client, _, current_user, _, second_user = sync_context
    first_id = uuid.uuid4()
    second_id = uuid.uuid4()
    records = [
        transaction_payload(client_record_id=first_id),
        transaction_payload(client_record_id=second_id, amount_in_minor=5000),
    ]
    response = await client.post(
        "/api/v1/sync/claim",
        json={"installation_id": INSTALLATION_ID, "transactions": records},
    )
    assert response.status_code == 200

    deleted_at = datetime(2026, 8, 4, 9, 0, tzinfo=UTC)
    response = await client.post(
        "/api/v1/sync/push",
        json={
            "installation_id": INSTALLATION_ID,
            "operations": [
                {
                    "operation_id": "task-delete-0002",
                    "action": "delete",
                    "client_record_id": str(second_id),
                    "client_updated_at": deleted_at.isoformat(),
                }
            ],
        },
    )
    assert response.status_code == 200

    first_page = await client.get("/api/v1/sync/pull", params={"limit": 1})
    assert first_page.status_code == 200
    assert first_page.json()["has_more"] is True
    assert first_page.json()["next_cursor"] is not None

    second_page = await client.get(
        "/api/v1/sync/pull",
        params={"limit": 1, "cursor": first_page.json()["next_cursor"]},
    )
    assert second_page.status_code == 200
    assert second_page.json()["has_more"] is False
    assert second_page.json()["next_cursor"] is not None
    pulled = first_page.json()["transactions"] + second_page.json()["transactions"]
    assert {item["client_record_id"] for item in pulled} == {
        str(first_id),
        str(second_id),
    }
    tombstone = next(
        item for item in pulled if item["client_record_id"] == str(second_id)
    )
    assert tombstone["deleted_at"] is not None

    final_cursor = second_page.json()["next_cursor"]
    no_changes = await client.get(
        "/api/v1/sync/pull",
        params={"cursor": final_cursor},
    )
    assert no_changes.status_code == 200
    assert no_changes.json() == {
        "transactions": [],
        "next_cursor": final_cursor,
        "has_more": False,
    }

    current_user["value"] = second_user
    isolated = await client.get("/api/v1/sync/pull")
    assert isolated.status_code == 200
    assert isolated.json()["transactions"] == []


@pytest.mark.asyncio
async def test_same_client_record_id_is_isolated_per_user(sync_context) -> None:
    client, session_factory, current_user, first_user, second_user = sync_context
    record_id = uuid.uuid4()
    first_payload = transaction_payload(
        client_record_id=record_id, amount_in_minor=1000
    )
    second_payload = transaction_payload(
        client_record_id=record_id, amount_in_minor=2000
    )

    assert (
        await client.post(
            "/api/v1/sync/claim",
            json={
                "installation_id": INSTALLATION_ID,
                "transactions": [first_payload],
            },
        )
    ).status_code == 200
    current_user["value"] = second_user
    assert (
        await client.post(
            "/api/v1/sync/claim",
            json={
                "installation_id": INSTALLATION_ID,
                "transactions": [second_payload],
            },
        )
    ).status_code == 200

    async with session_factory() as session:
        count = await session.scalar(select(func.count()).select_from(CloudTransaction))
        first_amount = await session.scalar(
            select(CloudTransaction.amount_in_minor).where(
                CloudTransaction.user_id == first_user.id
            )
        )
        second_amount = await session.scalar(
            select(CloudTransaction.amount_in_minor).where(
                CloudTransaction.user_id == second_user.id
            )
        )
    assert count == 2
    assert first_amount == 1000
    assert second_amount == 2000


@pytest.mark.asyncio
async def test_pull_rejects_invalid_cursor(sync_context) -> None:
    client, _, _, _, _ = sync_context

    response = await client.get(
        "/api/v1/sync/pull",
        params={"cursor": "not-a-valid-cursor"},
    )

    assert response.status_code == 400
    assert response.json() == {"detail": "Invalid sync cursor."}


@pytest.mark.asyncio
async def test_push_rejects_duplicate_operation_ids(sync_context) -> None:
    client, _, _, _, _ = sync_context
    record_id = uuid.uuid4()
    payload = transaction_payload(client_record_id=record_id)
    operation = {
        "operation_id": "duplicate-task-01",
        "action": "upsert",
        "client_record_id": str(record_id),
        "client_updated_at": payload["client_updated_at"],
        "transaction": payload,
    }

    response = await client.post(
        "/api/v1/sync/push",
        json={
            "installation_id": INSTALLATION_ID,
            "operations": [operation, operation],
        },
    )

    assert response.status_code == 422
