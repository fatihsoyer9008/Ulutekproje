import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

import httpx
import pytest
import pytest_asyncio
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_current_user
from app.core.database import Base, get_db_session
from app.main import app
from app.models.cloud_receipt import CloudReceipt, CloudReceiptStatus
from app.models.user import User


def _receipt(
    *,
    user_id: uuid.UUID,
    status: CloudReceiptStatus,
    merchant_name: str = "Test Market",
    total_amount_in_minor: int = 1000,
) -> CloudReceipt:
    now = datetime.now(UTC)
    return CloudReceipt(
        user_id=user_id,
        client_record_id=uuid.uuid4(),
        installation_id_hash="a" * 64,
        merchant_name=merchant_name,
        total_amount_in_minor=total_amount_in_minor,
        status=status,
        is_parse_successful=True,
        client_created_at=now,
        client_updated_at=now,
    )


@pytest_asyncio.fixture
async def pending_context() -> AsyncIterator[
    tuple[httpx.AsyncClient, async_sessionmaker[AsyncSession], User, User]
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
        owner = User(email="pending-owner@example.com")
        other = User(email="pending-other@example.com")
        session.add_all([owner, other])
        await session.commit()

    active_user_id: dict[str, uuid.UUID] = {"value": owner.id}

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_current_user(
        db: AsyncSession = Depends(get_db_session),
    ) -> User:
        current = await db.get(User, active_user_id["value"])
        assert current is not None
        return current

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_current_user

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as client:
        yield client, session_factory, owner, other

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_list_pending_returns_only_owners_drafts(pending_context) -> None:
    client, session_factory, owner, other = pending_context

    async with session_factory() as session:
        own_draft = _receipt(user_id=owner.id, status=CloudReceiptStatus.draft)
        own_approved = _receipt(user_id=owner.id, status=CloudReceiptStatus.approved)
        foreign_draft = _receipt(user_id=other.id, status=CloudReceiptStatus.draft)
        session.add_all([own_draft, own_approved, foreign_draft])
        await session.commit()
        own_draft_id = own_draft.id

    response = await client.get("/api/v1/receipts/pending")

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["id"] == str(own_draft_id)


@pytest.mark.asyncio
async def test_approve_applies_overrides_and_flips_status(pending_context) -> None:
    client, session_factory, owner, _other = pending_context

    async with session_factory() as session:
        draft = _receipt(
            user_id=owner.id,
            status=CloudReceiptStatus.draft,
            merchant_name="Original Market",
            total_amount_in_minor=500,
        )
        session.add(draft)
        await session.commit()
        draft_id = draft.id

    response = await client.post(
        f"/api/v1/receipts/{draft_id}/approve",
        json={"merchant_name": "Edited Market", "total_amount_in_minor": 750},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["merchant_name"] == "Edited Market"
    assert body["total_amount_in_minor"] == 750

    async with session_factory() as session:
        stored = await session.get(CloudReceipt, draft_id)
        assert stored is not None
        assert stored.status == CloudReceiptStatus.approved
        assert stored.merchant_name == "Edited Market"

    listing = await client.get("/api/v1/receipts/pending")
    assert listing.json() == []


@pytest.mark.asyncio
async def test_reject_flips_status_and_removes_from_pending(pending_context) -> None:
    client, session_factory, owner, _other = pending_context

    async with session_factory() as session:
        draft = _receipt(user_id=owner.id, status=CloudReceiptStatus.draft)
        session.add(draft)
        await session.commit()
        draft_id = draft.id

    response = await client.post(f"/api/v1/receipts/{draft_id}/reject")

    assert response.status_code == 200
    assert response.json()["id"] == str(draft_id)

    async with session_factory() as session:
        stored = await session.get(CloudReceipt, draft_id)
        assert stored is not None
        assert stored.status == CloudReceiptStatus.rejected

    listing = await client.get("/api/v1/receipts/pending")
    assert listing.json() == []


@pytest.mark.asyncio
async def test_approve_unknown_receipt_returns_404(pending_context) -> None:
    client, _session_factory, _owner, _other = pending_context

    response = await client.post(f"/api/v1/receipts/{uuid.uuid4()}/approve")

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_approve_another_users_draft_returns_404(pending_context) -> None:
    client, session_factory, _owner, other = pending_context

    async with session_factory() as session:
        foreign_draft = _receipt(user_id=other.id, status=CloudReceiptStatus.draft)
        session.add(foreign_draft)
        await session.commit()
        foreign_draft_id = foreign_draft.id

    response = await client.post(f"/api/v1/receipts/{foreign_draft_id}/approve")

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_approve_already_approved_receipt_returns_404(pending_context) -> None:
    client, session_factory, owner, _other = pending_context

    async with session_factory() as session:
        already_approved = _receipt(
            user_id=owner.id, status=CloudReceiptStatus.approved
        )
        session.add(already_approved)
        await session.commit()
        receipt_id = already_approved.id

    response = await client.post(f"/api/v1/receipts/{receipt_id}/approve")

    assert response.status_code == 404
