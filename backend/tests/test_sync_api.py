import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_current_user, get_debt_summary_cache
from app.core.database import Base, get_db_session
from app.main import app
from app.models.cloud_receipt import CloudReceipt
from app.models.cloud_transaction import CloudTransaction
from app.models.group import Group, GroupMember, GroupRole
from app.models.group_expense import (
    ExpenseShare,
    ExpenseShareStatus,
    ExpenseSplitType,
    GroupExpense,
)
from app.models.group_sync_operation import GroupSyncOperation
from app.models.settlement import Settlement
from app.models.sync_claim_request import SyncClaimRequest
from app.models.user import User

INSTALLATION_ID = "installation-sync-test-1234"


class _FakeDebtSummaryCache:
    async def invalidate(self, group_id: uuid.UUID) -> None:
        del group_id

    async def invalidate_best_effort(self, group_id: uuid.UUID) -> bool:
        del group_id
        return True


@pytest.mark.asyncio
async def test_group_sync_push_creates_expense_and_replays_idempotently(
    sync_context,
) -> None:
    client, session_factory, _, first_user, second_user = sync_context
    async with session_factory() as session:
        group = Group(name="Sync Group", currency="TRY", created_by=first_user.id)
        session.add(group)
        await session.flush()
        session.add_all(
            [
                GroupMember(
                    group_id=group.id, user_id=first_user.id, role=GroupRole.owner
                ),
                GroupMember(
                    group_id=group.id, user_id=second_user.id, role=GroupRole.member
                ),
            ]
        )
        await session.commit()

    record_id = uuid.uuid4()
    envelope = {
        "operation_type": "groupExpenseCreate",
        "group_id": str(group.id),
        "client_record_id": str(record_id),
        "owner_key": f"user:{first_user.id}",
        "sync_state": "pending",
        "payload": {"local_snapshot": True},
        "sync_payload": {
            "title": "Offline market",
            "note": None,
            "expense_date": "2026-08-17T12:00:00Z",
            "total_amount_in_minor": 12000,
            "currency": "TRY",
            "receipt_id": None,
            "payer_user_id": str(first_user.id),
            "split": {
                "type": "percentage",
                "shares": [
                    {"user_id": str(first_user.id), "percentage_basis_points": 3333},
                    {"user_id": str(second_user.id), "percentage_basis_points": 6667},
                ],
            },
        },
    }
    headers = {"Idempotency-Key": str(record_id)}

    first = await client.post(
        "/api/v1/sync/groups/push", json=envelope, headers=headers
    )
    replay = await client.post(
        "/api/v1/sync/groups/push", json=envelope, headers=headers
    )

    assert first.status_code == 200
    assert first.json() == {"operation_id": str(record_id), "status": "accepted"}
    assert replay.status_code == 200
    assert replay.json() == {"operation_id": str(record_id), "status": "duplicate"}
    assert replay.headers["Idempotency-Replayed"] == "true"
    async with session_factory() as session:
        stored_expense = await session.scalar(
            select(GroupExpense).where(GroupExpense.group_id == group.id)
        )
        assert stored_expense is not None
        shares = (
            await session.scalars(
                select(ExpenseShare).where(ExpenseShare.expense_id == stored_expense.id)
            )
        ).all()
    assert {share.user_id: share.amount_in_minor for share in shares} == {
        first_user.id: 4000,
        second_user.id: 8000,
    }


@pytest.mark.asyncio
async def test_group_sync_push_creates_settlement_and_replays_idempotently(
    sync_context,
) -> None:
    client, session_factory, _, first_user, second_user = sync_context
    async with session_factory() as session:
        group = Group(name="Settlement Sync", currency="TRY", created_by=first_user.id)
        session.add(group)
        await session.flush()
        session.add_all(
            [
                GroupMember(
                    group_id=group.id, user_id=first_user.id, role=GroupRole.owner
                ),
                GroupMember(
                    group_id=group.id, user_id=second_user.id, role=GroupRole.member
                ),
            ]
        )
        await session.commit()

    record_id = uuid.uuid4()
    envelope = {
        "operation_type": "settlementCreate",
        "group_id": str(group.id),
        "client_record_id": str(record_id),
        "owner_key": f"user:{first_user.id}",
        "sync_state": "pending",
        "payload": {
            "from_user_id": str(first_user.id),
            "to_user_id": str(second_user.id),
            "amount_in_minor": 2500,
            "currency": "TRY",
            "settled_at": "2026-08-17T13:00:00Z",
            "note": "Offline ödeme",
        },
    }
    headers = {"Idempotency-Key": str(record_id)}

    first = await client.post(
        "/api/v1/sync/groups/push", json=envelope, headers=headers
    )
    replay = await client.post(
        "/api/v1/sync/groups/push", json=envelope, headers=headers
    )

    assert first.json() == {"operation_id": str(record_id), "status": "accepted"}
    assert replay.json() == {"operation_id": str(record_id), "status": "duplicate"}
    async with session_factory() as session:
        settlements = (await session.scalars(select(Settlement))).all()
    assert len(settlements) == 1
    assert settlements[0].amount_in_minor == 2500


@pytest.mark.asyncio
async def test_group_sync_push_rejects_foreign_owner_scope(sync_context) -> None:
    client, _, _, first_user, _ = sync_context
    record_id = uuid.uuid4()
    response = await client.post(
        "/api/v1/sync/groups/push",
        headers={"Idempotency-Key": str(record_id)},
        json={
            "operation_type": "settlementCreate",
            "group_id": str(uuid.uuid4()),
            "client_record_id": str(record_id),
            "owner_key": f"user:{uuid.uuid4()}",
            "sync_state": "pending",
            "payload": {},
        },
    )

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "owner_scope_mismatch"


@pytest.mark.asyncio
async def test_group_sync_pushes_expense_share_crud_with_durable_idempotency(
    sync_context,
) -> None:
    client, session_factory, _, first_user, second_user = sync_context
    async with session_factory() as session:
        group = Group(name="Share Sync", currency="TRY", created_by=first_user.id)
        session.add(group)
        await session.flush()
        session.add_all(
            [
                GroupMember(
                    group_id=group.id, user_id=first_user.id, role=GroupRole.owner
                ),
                GroupMember(
                    group_id=group.id, user_id=second_user.id, role=GroupRole.member
                ),
            ]
        )
        expense = GroupExpense(
            group_id=group.id,
            payer_user_id=first_user.id,
            created_by_id=first_user.id,
            created_by=first_user.id,
            title="Offline share",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=1000,
            currency="TRY",
            split_type=ExpenseSplitType.fixed_amount,
        )
        session.add(expense)
        await session.flush()
        session.add(
            ExpenseShare(
                expense_id=expense.id,
                user_id=first_user.id,
                amount_in_minor=1000,
            )
        )
        await session.commit()

    async def push(
        operation_type: str,
        record_id: uuid.UUID,
        payload: dict[str, object],
    ) -> httpx.Response:
        return await client.post(
            "/api/v1/sync/groups/push",
            headers={"Idempotency-Key": str(record_id)},
            json={
                "operation_type": operation_type,
                "group_id": str(group.id),
                "client_record_id": str(record_id),
                "owner_key": f"user:{first_user.id}",
                "sync_state": (
                    "pendingDelete"
                    if operation_type == "expenseShareDelete"
                    else "pending"
                ),
                "payload": payload,
            },
        )

    share_payload = {
        "expense_id": str(expense.id),
        "user_id": str(second_user.id),
        "display_name": "Second User",
        "amount_in_minor": 0,
        "status": "open",
        "settled_at": None,
    }
    create_id, update_id, delete_id = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    created = await push("expenseShareCreate", create_id, share_payload)
    updated = await push("expenseShareUpdate", update_id, share_payload)
    replay = await push("expenseShareUpdate", update_id, share_payload)
    conflicting = await push(
        "expenseShareUpdate", update_id, {**share_payload, "amount_in_minor": 1}
    )
    deleted = await push(
        "expenseShareDelete",
        delete_id,
        {"expense_id": str(expense.id), "user_id": str(second_user.id)},
    )

    assert created.json()["status"] == "accepted"
    assert updated.json()["status"] == "accepted"
    assert replay.json()["status"] == "duplicate"
    assert replay.headers["Idempotency-Replayed"] == "true"
    assert conflicting.status_code == 409
    assert conflicting.json()["detail"]["code"] == "idempotency_conflict"
    assert deleted.json()["status"] == "accepted"
    async with session_factory() as session:
        assert await session.get(ExpenseShare, (expense.id, second_user.id)) is None
        receipts = (await session.scalars(select(GroupSyncOperation))).all()
    assert len(receipts) == 3


@pytest.mark.asyncio
async def test_group_sync_expense_share_reports_financial_lock_conflict(
    sync_context,
) -> None:
    client, session_factory, _, first_user, _ = sync_context
    async with session_factory() as session:
        group = Group(name="Locked Sync", currency="TRY", created_by=first_user.id)
        session.add(group)
        await session.flush()
        session.add(
            GroupMember(group_id=group.id, user_id=first_user.id, role=GroupRole.owner)
        )
        expense = GroupExpense(
            group_id=group.id,
            payer_user_id=first_user.id,
            created_by_id=first_user.id,
            created_by=first_user.id,
            title="Locked",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=1000,
            currency="TRY",
            split_type=ExpenseSplitType.fixed_amount,
        )
        session.add(expense)
        await session.flush()
        session.add(
            ExpenseShare(
                expense_id=expense.id,
                user_id=first_user.id,
                amount_in_minor=1000,
                status=ExpenseShareStatus.settled,
                settled_at=datetime.now(UTC),
            )
        )
        await session.commit()

    record_id = uuid.uuid4()
    response = await client.post(
        "/api/v1/sync/groups/push",
        headers={"Idempotency-Key": str(record_id)},
        json={
            "operation_type": "expenseShareUpdate",
            "group_id": str(group.id),
            "client_record_id": str(record_id),
            "owner_key": f"user:{first_user.id}",
            "sync_state": "pending",
            "payload": {
                "expense_id": str(expense.id),
                "user_id": str(first_user.id),
                "amount_in_minor": 900,
            },
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "expense_financially_locked"


@pytest.mark.asyncio
async def test_group_sync_pushes_expense_update_and_delete_idempotently(
    sync_context,
) -> None:
    client, session_factory, _, first_user, second_user = sync_context
    async with session_factory() as session:
        group = Group(
            name="Expense mutation sync",
            currency="TRY",
            created_by=first_user.id,
        )
        session.add(group)
        await session.flush()
        session.add_all(
            [
                GroupMember(
                    group_id=group.id,
                    user_id=first_user.id,
                    role=GroupRole.owner,
                ),
                GroupMember(
                    group_id=group.id,
                    user_id=second_user.id,
                    role=GroupRole.member,
                ),
            ]
        )
        expense = GroupExpense(
            group_id=group.id,
            payer_user_id=first_user.id,
            created_by_id=first_user.id,
            created_by=first_user.id,
            title="Eski başlık",
            expense_date=datetime(2026, 8, 17, 10, tzinfo=UTC),
            total_amount_in_minor=1000,
            currency="TRY",
            split_type=ExpenseSplitType.fixed_amount,
        )
        expense.shares = [
            ExpenseShare(user_id=first_user.id, amount_in_minor=500),
            ExpenseShare(user_id=second_user.id, amount_in_minor=500),
        ]
        session.add(expense)
        await session.commit()

    async def push(
        operation_type: str,
        operation_id: uuid.UUID,
        body: dict[str, object],
    ) -> httpx.Response:
        return await client.post(
            "/api/v1/sync/groups/push",
            headers={"Idempotency-Key": str(operation_id)},
            json={
                "operation_type": operation_type,
                "group_id": str(group.id),
                "client_record_id": str(operation_id),
                "owner_key": f"user:{first_user.id}",
                "sync_state": (
                    "pendingDelete"
                    if operation_type == "groupExpenseDelete"
                    else "pending"
                ),
                "payload": body,
            },
        )

    update_payload = {
        "id": str(expense.id),
        "group_id": str(group.id),
        "receipt_id": None,
        "payer_user_id": str(second_user.id),
        "created_by": str(first_user.id),
        "title": "Güncel başlık",
        "note": "Offline düzeltme",
        "expense_date": "2026-08-17T11:00:00Z",
        "total_amount_in_minor": 1200,
        "currency": "TRY",
        "split_type": "fixed_amount",
        "is_financially_locked": False,
        "shares": [
            {"user_id": str(first_user.id), "amount_in_minor": 400},
            {"user_id": str(second_user.id), "amount_in_minor": 800},
        ],
        "line_item_assignments": [],
        "extra_amounts": [],
        "created_at": "2026-08-17T10:00:00Z",
        "updated_at": "2026-08-17T11:00:00Z",
        "deleted_at": None,
    }
    update_id = uuid.uuid4()
    first_update = await push("groupExpenseUpdate", update_id, update_payload)
    replayed_update = await push("groupExpenseUpdate", update_id, update_payload)
    conflicting_replay = await push(
        "groupExpenseUpdate",
        update_id,
        {**update_payload, "title": "Farklı tekrar"},
    )

    assert first_update.json()["status"] == "accepted"
    assert replayed_update.json()["status"] == "duplicate"
    assert replayed_update.headers["Idempotency-Replayed"] == "true"
    assert conflicting_replay.status_code == 409
    assert conflicting_replay.json()["detail"]["code"] == "idempotency_conflict"

    delete_id = uuid.uuid4()
    delete_payload = {
        "group_id": str(group.id),
        "expense_id": str(expense.id),
    }
    first_delete = await push("groupExpenseDelete", delete_id, delete_payload)
    replayed_delete = await push("groupExpenseDelete", delete_id, delete_payload)
    update_after_delete = await push(
        "groupExpenseUpdate",
        uuid.uuid4(),
        update_payload,
    )

    assert first_delete.json()["status"] == "accepted"
    assert replayed_delete.json()["status"] == "duplicate"
    assert update_after_delete.status_code == 409
    assert update_after_delete.json()["detail"]["code"] == "record_soft_deleted"

    async with session_factory() as session:
        stored = await session.get(GroupExpense, expense.id)
        assert stored is not None
        assert stored.title == "Güncel başlık"
        assert stored.payer_user_id == second_user.id
        assert stored.total_amount_in_minor == 1200
        assert stored.deleted_at is not None
        shares = (
            await session.scalars(
                select(ExpenseShare).where(ExpenseShare.expense_id == expense.id)
            )
        ).all()
        receipts = (await session.scalars(select(GroupSyncOperation))).all()
    assert {share.user_id: share.amount_in_minor for share in shares} == {
        first_user.id: 400,
        second_user.id: 800,
    }
    assert len(receipts) == 2


@pytest.mark.asyncio
async def test_group_sync_expense_mutations_enforce_settlement_lock(
    sync_context,
) -> None:
    client, session_factory, _, first_user, second_user = sync_context
    async with session_factory() as session:
        group = Group(
            name="Locked expense mutation",
            currency="TRY",
            created_by=first_user.id,
        )
        session.add(group)
        await session.flush()
        session.add_all(
            [
                GroupMember(
                    group_id=group.id,
                    user_id=first_user.id,
                    role=GroupRole.owner,
                ),
                GroupMember(
                    group_id=group.id,
                    user_id=second_user.id,
                    role=GroupRole.member,
                ),
            ]
        )
        expense = GroupExpense(
            group_id=group.id,
            payer_user_id=first_user.id,
            created_by_id=first_user.id,
            created_by=first_user.id,
            title="Kilitli masraf",
            expense_date=datetime(2026, 8, 17, 10, tzinfo=UTC),
            total_amount_in_minor=1000,
            currency="TRY",
            split_type=ExpenseSplitType.fixed_amount,
        )
        expense.shares = [
            ExpenseShare(user_id=first_user.id, amount_in_minor=500),
            ExpenseShare(user_id=second_user.id, amount_in_minor=500),
        ]
        session.add(expense)
        await session.flush()
        session.add(
            Settlement(
                group_id=group.id,
                from_user_id=second_user.id,
                to_user_id=first_user.id,
                amount_in_minor=100,
                currency="TRY",
                settled_at=datetime(2026, 8, 17, 12, tzinfo=UTC),
            )
        )
        await session.commit()

    base_payload = {
        "id": str(expense.id),
        "group_id": str(group.id),
        "receipt_id": None,
        "payer_user_id": str(first_user.id),
        "title": "Kilitli masraf",
        "note": None,
        "expense_date": "2026-08-17T10:00:00Z",
        "total_amount_in_minor": 1000,
        "currency": "TRY",
        "split_type": "fixed_amount",
        "shares": [
            {"user_id": str(first_user.id), "amount_in_minor": 500},
            {"user_id": str(second_user.id), "amount_in_minor": 500},
        ],
    }

    async def push(operation_type: str, body: dict[str, object]) -> httpx.Response:
        operation_id = uuid.uuid4()
        return await client.post(
            "/api/v1/sync/groups/push",
            headers={"Idempotency-Key": str(operation_id)},
            json={
                "operation_type": operation_type,
                "group_id": str(group.id),
                "client_record_id": str(operation_id),
                "owner_key": f"user:{first_user.id}",
                "sync_state": (
                    "pendingDelete"
                    if operation_type == "groupExpenseDelete"
                    else "pending"
                ),
                "payload": body,
            },
        )

    metadata_update = await push(
        "groupExpenseUpdate",
        {**base_payload, "title": "Kilitliyken açıklama düzeltildi"},
    )
    financial_update = await push(
        "groupExpenseUpdate",
        {
            **base_payload,
            "total_amount_in_minor": 1200,
            "shares": [
                {"user_id": str(first_user.id), "amount_in_minor": 600},
                {"user_id": str(second_user.id), "amount_in_minor": 600},
            ],
        },
    )
    delete = await push(
        "groupExpenseDelete",
        {"group_id": str(group.id), "expense_id": str(expense.id)},
    )

    assert metadata_update.json()["status"] == "accepted"
    assert financial_update.status_code == 409
    assert financial_update.json()["detail"]["code"] == "expense_financially_locked"
    assert delete.status_code == 409
    assert delete.json()["detail"]["code"] == "expense_financially_locked"


@pytest.mark.asyncio
async def test_group_sync_expense_mutations_enforce_rbac_and_expected_version(
    sync_context,
) -> None:
    client, session_factory, current_user, first_user, second_user = sync_context
    async with session_factory() as session:
        group = Group(
            name="Expense mutation RBAC",
            currency="TRY",
            created_by=first_user.id,
        )
        session.add(group)
        await session.flush()
        session.add_all(
            [
                GroupMember(
                    group_id=group.id,
                    user_id=first_user.id,
                    role=GroupRole.owner,
                ),
                GroupMember(
                    group_id=group.id,
                    user_id=second_user.id,
                    role=GroupRole.member,
                ),
            ]
        )
        expense = GroupExpense(
            group_id=group.id,
            payer_user_id=first_user.id,
            created_by_id=first_user.id,
            created_by=first_user.id,
            title="Yetki kontrollü masraf",
            expense_date=datetime(2026, 8, 17, 10, tzinfo=UTC),
            total_amount_in_minor=1000,
            currency="TRY",
            split_type=ExpenseSplitType.fixed_amount,
        )
        expense.shares = [
            ExpenseShare(user_id=first_user.id, amount_in_minor=500),
            ExpenseShare(user_id=second_user.id, amount_in_minor=500),
        ]
        session.add(expense)
        await session.commit()

    update_payload = {
        "id": str(expense.id),
        "group_id": str(group.id),
        "payer_user_id": str(first_user.id),
        "title": "Yetkisiz değişiklik",
        "expense_date": "2026-08-17T10:00:00Z",
        "total_amount_in_minor": 1000,
        "currency": "TRY",
        "split_type": "fixed_amount",
        "shares": [
            {"user_id": str(first_user.id), "amount_in_minor": 500},
            {"user_id": str(second_user.id), "amount_in_minor": 500},
        ],
    }

    async def push(
        *,
        operation_type: str,
        actor: User,
        body: dict[str, object],
    ) -> httpx.Response:
        current_user["value"] = actor
        operation_id = uuid.uuid4()
        return await client.post(
            "/api/v1/sync/groups/push",
            headers={"Idempotency-Key": str(operation_id)},
            json={
                "operation_type": operation_type,
                "group_id": str(group.id),
                "client_record_id": str(operation_id),
                "owner_key": f"user:{actor.id}",
                "sync_state": (
                    "pendingDelete"
                    if operation_type == "groupExpenseDelete"
                    else "pending"
                ),
                "payload": body,
            },
        )

    forbidden = await push(
        operation_type="groupExpenseUpdate",
        actor=second_user,
        body=update_payload,
    )
    stale = await push(
        operation_type="groupExpenseDelete",
        actor=first_user,
        body={
            "group_id": str(group.id),
            "expense_id": str(expense.id),
            "expected_updated_at": "2020-01-01T00:00:00Z",
        },
    )

    assert forbidden.status_code == 403
    assert forbidden.json()["detail"]["code"] == "group_forbidden"
    assert stale.status_code == 409
    assert stale.json()["detail"]["code"] == "version_mismatch"


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

    async def override_debt_cache() -> _FakeDebtSummaryCache:
        return _FakeDebtSummaryCache()

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_current_user
    app.dependency_overrides[get_debt_summary_cache] = override_debt_cache

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

    idempotency_headers = {"Idempotency-Key": "claim-retry-0001"}
    first = await client.post(
        "/api/v1/sync/claim",
        json=request,
        headers=idempotency_headers,
    )
    second = await client.post(
        "/api/v1/sync/claim",
        json=request,
        headers=idempotency_headers,
    )
    duplicate = await client.post(
        "/api/v1/sync/claim",
        json=request,
        headers={"Idempotency-Key": "claim-retry-0002"},
    )

    assert first.status_code == 200
    assert first.json()["owner_key"] == f"user:{first_user.id}"
    assert first.json()["results"][0]["status"] == "accepted"
    assert second.status_code == 200
    assert second.json() == first.json()
    assert duplicate.status_code == 200
    assert duplicate.json()["results"][0]["status"] == "duplicate"

    async with session_factory() as session:
        stored = (await session.scalars(select(CloudTransaction))).all()
        claim_requests = (await session.scalars(select(SyncClaimRequest))).all()
    assert len(stored) == 1
    assert stored[0].installation_id_hash != INSTALLATION_ID
    assert len(stored[0].installation_id_hash) == 64
    assert len(claim_requests) == 2
    assert all(
        item.idempotency_key_hash != "claim-retry-0001" for item in claim_requests
    )


@pytest.mark.asyncio
async def test_claim_returns_per_record_results_for_partial_failure(
    sync_context,
) -> None:
    client, _, _, _, _ = sync_context
    valid_record = transaction_payload()
    invalid_record = transaction_payload()
    invalid_record["amount_in_minor"] = -1

    response = await client.post(
        "/api/v1/sync/claim",
        json={
            "installation_id": INSTALLATION_ID,
            "transactions": [valid_record, invalid_record, valid_record],
        },
        headers={"Idempotency-Key": "partial-claim-0001"},
    )

    assert response.status_code == 200
    assert [result["status"] for result in response.json()["results"]] == [
        "accepted",
        "rejected",
        "duplicate",
    ]
    assert (
        response.json()["results"][1]["client_record_id"]
        == invalid_record["client_record_id"]
    )


@pytest.mark.asyncio
async def test_claim_rejects_reused_idempotency_key_with_different_body(
    sync_context,
) -> None:
    client, _, _, _, _ = sync_context
    headers = {"Idempotency-Key": "conflicting-claim-key-0001"}
    first = await client.post(
        "/api/v1/sync/claim",
        json={
            "installation_id": INSTALLATION_ID,
            "transactions": [transaction_payload(amount_in_minor=1000)],
        },
        headers=headers,
    )
    conflicting = await client.post(
        "/api/v1/sync/claim",
        json={
            "installation_id": INSTALLATION_ID,
            "transactions": [transaction_payload(amount_in_minor=2000)],
        },
        headers=headers,
    )

    assert first.status_code == 200
    assert conflicting.status_code == 409
    assert conflicting.json() == {
        "detail": "Idempotency-Key was already used for a different request."
    }


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
        headers={"Idempotency-Key": "push-setup-claim-0001"},
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
        headers={"Idempotency-Key": "pull-setup-claim-0001"},
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
        "cloud_receipts": [],
        "cloud_receipts_next_cursor": None,
        "cloud_receipts_has_more": False,
    }

    current_user["value"] = second_user
    isolated = await client.get("/api/v1/sync/pull")
    assert isolated.status_code == 200
    assert isolated.json()["transactions"] == []


@pytest.mark.asyncio
async def test_pull_includes_personal_receipts_but_excludes_group_linked_ones(
    sync_context,
) -> None:
    client, session_factory, _, first_user, _ = sync_context
    now = datetime(2026, 8, 18, 10, 0, tzinfo=UTC)
    personal_receipt_id = uuid.uuid4()
    group_receipt_id = uuid.uuid4()

    async with session_factory() as session:
        group = Group(name="Receipt Group", currency="TRY", created_by=first_user.id)
        session.add(group)
        await session.flush()

        session.add_all(
            [
                CloudReceipt(
                    id=personal_receipt_id,
                    user_id=first_user.id,
                    client_record_id=uuid.uuid4(),
                    installation_id_hash="n8n-import-hash",
                    merchant_name="Kişisel Market",
                    total_amount_in_minor=1000,
                    client_created_at=now,
                    client_updated_at=now,
                ),
                CloudReceipt(
                    id=group_receipt_id,
                    user_id=first_user.id,
                    client_record_id=uuid.uuid4(),
                    installation_id_hash="group-ocr-hash",
                    merchant_name="Grup Market",
                    total_amount_in_minor=2000,
                    client_created_at=now,
                    client_updated_at=now,
                ),
            ]
        )
        await session.flush()
        session.add(
            GroupExpense(
                group_id=group.id,
                receipt_id=group_receipt_id,
                payer_user_id=first_user.id,
                created_by_id=first_user.id,
                created_by=first_user.id,
                title="Grup masrafı",
                expense_date=now,
                total_amount_in_minor=2000,
                split_type=ExpenseSplitType.equal,
            )
        )
        await session.commit()

    response = await client.get("/api/v1/sync/pull")

    assert response.status_code == 200
    receipt_ids = {item["id"] for item in response.json()["cloud_receipts"]}
    assert receipt_ids == {str(personal_receipt_id)}


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
            headers={"Idempotency-Key": "first-user-claim-0001"},
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
            headers={"Idempotency-Key": "second-user-claim-0001"},
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
