import asyncio
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
import pytest
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.api.dependencies import get_current_user, get_debt_summary_cache
from app.core.database import get_db_session
from app.main import app
from app.models.cloud_transaction import CloudTransaction
from app.models.expense_idempotency import GroupExpenseIdempotencyRecord
from app.models.group import Group, GroupMember, GroupRole
from app.models.group_expense import GroupExpense
from app.models.group_sync_change import GroupSyncChange
from app.models.group_sync_operation import GroupSyncOperation
from app.models.user import User
from app.services.sync_service import SyncService
from app.sync_schemas import PushOperation, TransactionSyncPayload
from tests.postgres_support import postgres_test_database_url


class _NoopDebtSummaryCache:
    async def invalidate(self, group_id: uuid.UUID) -> None:
        del group_id

    async def invalidate_best_effort(self, group_id: uuid.UUID) -> bool:
        del group_id
        return True


class _PostgresGroupSyncDevice:
    def __init__(
        self,
        *,
        name: str,
        client: httpx.AsyncClient,
        group_id: uuid.UUID,
        owner_id: uuid.UUID,
    ) -> None:
        self.name = name
        self.client = client
        self.group_id = group_id
        self.owner_id = owner_id
        self.cursor: str | None = None
        self.expenses: dict[str, dict[str, Any]] = {}
        self.tombstones: set[str] = set()

    async def push(
        self,
        *,
        operation_type: str,
        operation_id: uuid.UUID,
        payload: dict[str, Any],
    ) -> httpx.Response:
        sync_state = (
            "pendingDelete" if operation_type == "groupExpenseDelete" else "pending"
        )
        return await self.client.post(
            "/api/v1/sync/groups/push",
            headers={"Idempotency-Key": str(operation_id)},
            json={
                "operation_type": operation_type,
                "group_id": str(self.group_id),
                "client_record_id": str(operation_id),
                "owner_key": f"user:{self.owner_id}",
                "sync_state": sync_state,
                "payload": payload,
            },
        )

    async def pull(self) -> list[dict[str, Any]]:
        params = {} if self.cursor is None else {"cursor": self.cursor}
        response = await self.client.get(
            "/api/v1/sync/groups/pull",
            params=params,
        )
        assert response.status_code == 200, f"{self.name} pull failed: {response.text}"
        body = response.json()
        self.cursor = body["next_cursor"]
        changes = body["changes"]
        for change in changes:
            operation = change["operation"]
            payload = operation["payload"]
            if operation["operation_type"] == "groupExpenseDelete":
                expense_id = payload["expense_id"]
                self.expenses.pop(expense_id, None)
                self.tombstones.add(expense_id)
            else:
                expense_id = payload["id"]
                self.expenses[expense_id] = payload
                self.tombstones.discard(expense_id)
        return changes


@pytest.mark.asyncio
async def test_concurrent_create_keeps_newest_client_version() -> None:
    database_url = postgres_test_database_url()
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


@pytest.mark.asyncio
async def test_two_devices_complete_group_offline_sync_against_postgres() -> None:
    """Exercises offline push, cross-device pull, duplicate, tombstone and conflict."""
    engine = create_async_engine(postgres_test_database_url())
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    owner = User(
        email=f"group-sync-pg-owner-{uuid.uuid4()}@example.com",
        display_name="PostgreSQL Sync Owner",
    )
    member = User(
        email=f"group-sync-pg-member-{uuid.uuid4()}@example.com",
        display_name="PostgreSQL Sync Member",
    )
    group: Group | None = None

    try:
        async with session_factory() as session:
            session.add_all([owner, member])
            await session.flush()
            group = Group(
                name="PostgreSQL Two Device Sync",
                currency="TRY",
                created_by=owner.id,
            )
            session.add(group)
            await session.flush()
            session.add_all(
                [
                    GroupMember(
                        group_id=group.id,
                        user_id=owner.id,
                        role=GroupRole.owner,
                    ),
                    GroupMember(
                        group_id=group.id,
                        user_id=member.id,
                        role=GroupRole.member,
                    ),
                ]
            )
            await session.commit()

        async def override_db() -> AsyncIterator[AsyncSession]:
            async with session_factory() as session:
                yield session

        async def override_user() -> User:
            return owner

        async def override_cache() -> _NoopDebtSummaryCache:
            return _NoopDebtSummaryCache()

        app.dependency_overrides[get_db_session] = override_db
        app.dependency_overrides[get_current_user] = override_user
        app.dependency_overrides[get_debt_summary_cache] = override_cache

        transport_a = httpx.ASGITransport(app=app)
        transport_b = httpx.ASGITransport(app=app)
        async with (
            httpx.AsyncClient(
                transport=transport_a,
                base_url="http://device-a",
                headers={"X-Test-Device-ID": "postgres-device-a"},
            ) as client_a,
            httpx.AsyncClient(
                transport=transport_b,
                base_url="http://device-b",
                headers={"X-Test-Device-ID": "postgres-device-b"},
            ) as client_b,
        ):
            device_a = _PostgresGroupSyncDevice(
                name="device-a",
                client=client_a,
                group_id=group.id,
                owner_id=owner.id,
            )
            device_b = _PostgresGroupSyncDevice(
                name="device-b",
                client=client_b,
                group_id=group.id,
                owner_id=owner.id,
            )

            create_id = uuid.uuid4()
            offline_create = {
                "local_snapshot": {
                    "title": "Cihaz A çevrimdışı market",
                    "sync_state": "pending",
                }
            }
            create_sync_payload = {
                "title": "Cihaz A çevrimdışı market",
                "note": "PostgreSQL iki cihaz testi",
                "expense_date": "2026-08-18T08:00:00Z",
                "total_amount_in_minor": 10_000,
                "currency": "TRY",
                "receipt_id": None,
                "payer_user_id": str(owner.id),
                "split": {
                    "type": "fixed_amount",
                    "shares": [
                        {"user_id": str(owner.id), "amount_in_minor": 6_000},
                        {"user_id": str(member.id), "amount_in_minor": 4_000},
                    ],
                },
            }

            async with session_factory() as session:
                before_push = await session.scalar(
                    select(func.count())
                    .select_from(GroupExpense)
                    .where(GroupExpense.group_id == group.id)
                )
            assert before_push == 0

            first_push = await client_a.post(
                "/api/v1/sync/groups/push",
                headers={"Idempotency-Key": str(create_id)},
                json={
                    "operation_type": "groupExpenseCreate",
                    "group_id": str(group.id),
                    "client_record_id": str(create_id),
                    "owner_key": f"user:{owner.id}",
                    "sync_state": "pending",
                    "payload": offline_create,
                    "sync_payload": create_sync_payload,
                },
            )
            duplicate_push = await client_a.post(
                "/api/v1/sync/groups/push",
                headers={"Idempotency-Key": str(create_id)},
                json={
                    "operation_type": "groupExpenseCreate",
                    "group_id": str(group.id),
                    "client_record_id": str(create_id),
                    "owner_key": f"user:{owner.id}",
                    "sync_state": "pending",
                    "payload": offline_create,
                    "sync_payload": create_sync_payload,
                },
            )
            assert first_push.status_code == 200
            assert first_push.json()["status"] == "accepted"
            assert duplicate_push.status_code == 200
            assert duplicate_push.json()["status"] == "duplicate"
            assert duplicate_push.headers["Idempotency-Replayed"] == "true"

            device_b_create_changes = await device_b.pull()
            assert len(device_b_create_changes) == 1
            create_operation = device_b_create_changes[0]["operation"]
            assert create_operation["owner_key"] == f"user:{owner.id}"
            expense_id = create_operation["payload"]["id"]
            assert device_b.expenses[expense_id]["title"] == (
                "Cihaz A çevrimdışı market"
            )

            original_snapshot = device_b.expenses[expense_id]
            device_b_update = {
                **original_snapshot,
                "title": "Cihaz B güncelledi",
                "note": "Cihaz B online düzenleme",
                "expected_updated_at": original_snapshot["updated_at"],
            }
            update_id = uuid.uuid4()
            updated = await device_b.push(
                operation_type="groupExpenseUpdate",
                operation_id=update_id,
                payload=device_b_update,
            )
            assert updated.status_code == 200
            assert updated.json()["status"] == "accepted"

            stale_device_a_update = {
                **original_snapshot,
                "title": "Cihaz A stale düzenleme",
                "expected_updated_at": original_snapshot["updated_at"],
            }
            conflict = await device_a.push(
                operation_type="groupExpenseUpdate",
                operation_id=uuid.uuid4(),
                payload=stale_device_a_update,
            )
            assert conflict.status_code == 409
            assert conflict.json()["detail"]["code"] == "version_mismatch"

            device_a_changes = await device_a.pull()
            assert [
                change["operation"]["operation_type"] for change in device_a_changes
            ] == ["groupExpenseCreate", "groupExpenseUpdate"]
            latest_snapshot = device_a.expenses[expense_id]
            assert latest_snapshot["title"] == "Cihaz B güncelledi"

            delete_id = uuid.uuid4()
            delete_payload = {
                "group_id": str(group.id),
                "expense_id": expense_id,
                "expected_updated_at": latest_snapshot["updated_at"],
            }
            deleted = await device_a.push(
                operation_type="groupExpenseDelete",
                operation_id=delete_id,
                payload=delete_payload,
            )
            duplicate_delete = await device_a.push(
                operation_type="groupExpenseDelete",
                operation_id=delete_id,
                payload=delete_payload,
            )
            assert deleted.status_code == 200
            assert deleted.json()["status"] == "accepted"
            assert duplicate_delete.status_code == 200
            assert duplicate_delete.json()["status"] == "duplicate"

            device_b_final_changes = await device_b.pull()
            assert [
                change["operation"]["operation_type"]
                for change in device_b_final_changes
            ] == ["groupExpenseUpdate", "groupExpenseDelete"]
            assert expense_id not in device_b.expenses
            assert expense_id in device_b.tombstones
            assert await device_b.pull() == []

        async with session_factory() as session:
            expense_count = await session.scalar(
                select(func.count())
                .select_from(GroupExpense)
                .where(GroupExpense.group_id == group.id)
            )
            operation_count = await session.scalar(
                select(func.count())
                .select_from(GroupSyncOperation)
                .where(GroupSyncOperation.group_id == group.id)
            )
            create_receipt_count = await session.scalar(
                select(func.count())
                .select_from(GroupExpenseIdempotencyRecord)
                .where(GroupExpenseIdempotencyRecord.group_id == group.id)
            )
            change_count = await session.scalar(
                select(func.count())
                .select_from(GroupSyncChange)
                .where(GroupSyncChange.group_id == group.id)
            )
            stored_expense = await session.get(GroupExpense, uuid.UUID(expense_id))

        assert expense_count == 1
        assert create_receipt_count == 1
        assert operation_count == 2
        assert change_count == 3
        assert stored_expense is not None
        assert stored_expense.title == "Cihaz B güncelledi"
        assert stored_expense.deleted_at is not None
    finally:
        app.dependency_overrides.clear()
        if group is not None:
            async with session_factory() as session:
                await session.execute(delete(Group).where(Group.id == group.id))
                await session.execute(
                    delete(User).where(User.id.in_((owner.id, member.id)))
                )
                await session.commit()
        await engine.dispose()
