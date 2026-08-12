import asyncio
import os
import uuid
from collections.abc import AsyncIterator

import httpx
import pytest
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.api.dependencies import get_current_user
from app.core.database import get_db_session
from app.main import app
from app.models import Group, GroupExpense, GroupMember, GroupRole, User


@pytest.mark.asyncio
async def test_concurrent_posts_with_same_idempotency_key_create_one_expense() -> None:
    database_url = os.getenv("POSTGRES_TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is required for PostgreSQL tests")
    engine = create_async_engine(database_url)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    user = User(email=f"fast-split-{uuid.uuid4()}@example.com", display_name="Test")
    group = Group(name="Concurrent Fast Split", created_by=user.id)
    async with session_factory() as session:
        session.add(user)
        await session.flush()
        group.created_by = user.id
        session.add(group)
        await session.flush()
        session.add(
            GroupMember(group_id=group.id, user_id=user.id, role=GroupRole.owner)
        )
        await session.commit()

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_user() -> User:
        return user

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_user
    payload = {
        "receipt_id": None,
        "payer_user_id": str(user.id),
        "title": "Concurrent expense",
        "note": None,
        "expense_date": "2026-08-12T12:00:00Z",
        "total_amount_in_minor": 100,
        "currency": "TRY",
        "split": {"type": "equal", "member_ids": [str(user.id)]},
    }
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as client:
            responses = await asyncio.gather(
                *[
                    client.post(
                        f"/api/v1/groups/{group.id}/expenses",
                        json=payload,
                        headers={"Idempotency-Key": "concurrent-request-1"},
                    )
                    for _ in range(2)
                ]
            )
        assert sorted(response.status_code for response in responses) == [200, 201]
        assert responses[0].json() == responses[1].json()
        async with session_factory() as session:
            count = await session.scalar(
                select(func.count())
                .select_from(GroupExpense)
                .where(GroupExpense.group_id == group.id)
            )
            assert count == 1
    finally:
        app.dependency_overrides.clear()
        async with session_factory() as session:
            await session.execute(delete(Group).where(Group.id == group.id))
            await session.execute(delete(User).where(User.id == user.id))
            await session.commit()
        await engine.dispose()
