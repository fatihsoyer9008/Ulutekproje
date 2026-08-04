import base64
import binascii
import json
import uuid
from datetime import UTC, datetime
from typing import Literal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import privacy_hash, utc_now
from app.models.cloud_transaction import CloudTransaction
from app.models.user import User
from app.repositories.cloud_transactions import CloudTransactionRepository
from app.sync_schemas import (
    ClaimResponse,
    PullResponse,
    PushOperation,
    PushResponse,
    SyncedTransaction,
    SyncResult,
    TransactionSyncPayload,
)


class InvalidSyncCursor(ValueError):
    pass


class SyncService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.transactions = CloudTransactionRepository(db)

    async def claim(
        self,
        *,
        user: User,
        installation_id: str,
        transactions: list[TransactionSyncPayload],
    ) -> ClaimResponse:
        installation_hash = _installation_hash(installation_id)
        results = [
            await self._upsert(
                user=user,
                installation_hash=installation_hash,
                payload=payload,
            )
            for payload in transactions
        ]
        await self.db.commit()
        return ClaimResponse(owner_key=f"user:{user.id}", results=results)

    async def push(
        self,
        *,
        user: User,
        installation_id: str,
        operations: list[PushOperation],
    ) -> PushResponse:
        installation_hash = _installation_hash(installation_id)
        results: list[SyncResult] = []
        for operation in operations:
            if operation.action == "upsert":
                assert operation.transaction is not None
                result = await self._upsert(
                    user=user,
                    installation_hash=installation_hash,
                    payload=operation.transaction,
                    operation_id=operation.operation_id,
                )
            else:
                result = await self._delete(
                    user=user,
                    client_record_id=operation.client_record_id,
                    client_updated_at=operation.client_updated_at,
                    operation_id=operation.operation_id,
                )
            results.append(result)
        await self.db.commit()
        return PushResponse(results=results)

    async def pull(
        self,
        *,
        user: User,
        cursor: str | None,
        limit: int,
    ) -> PullResponse:
        after_updated_at, after_id = decode_cursor(cursor)
        records = await self.transactions.list_changes(
            user_id=user.id,
            limit=limit + 1,
            after_updated_at=after_updated_at,
            after_id=after_id,
        )
        has_more = len(records) > limit
        page = records[:limit]
        next_cursor = (
            encode_cursor(page[-1].updated_at, page[-1].id) if page else cursor
        )
        return PullResponse(
            transactions=[_serialize_transaction(item) for item in page],
            next_cursor=next_cursor,
            has_more=has_more,
        )

    async def _upsert(
        self,
        *,
        user: User,
        installation_hash: str,
        payload: TransactionSyncPayload,
        operation_id: str | None = None,
    ) -> SyncResult:
        existing = await self.transactions.get_for_user(
            user_id=user.id,
            client_record_id=payload.client_record_id,
        )
        now = utc_now()
        if existing is None:
            transaction = CloudTransaction(
                id=uuid.uuid4(),
                user_id=user.id,
                installation_id_hash=installation_hash,
                created_at=now,
                updated_at=now,
                deleted_at=None,
                **_payload_values(payload),
            )
            await self.transactions.add(transaction)
            return _result(transaction, "created", operation_id)

        freshness = _compare_timestamps(
            payload.client_updated_at,
            existing.client_updated_at,
        )
        if freshness < 0:
            return _result(existing, "conflict", operation_id)
        if freshness == 0:
            if _matches_payload(existing, payload) and existing.deleted_at is None:
                return _result(existing, "unchanged", operation_id)
            return _result(existing, "conflict", operation_id)

        for field, value in _payload_values(payload).items():
            setattr(existing, field, value)
        existing.installation_id_hash = installation_hash
        existing.deleted_at = None
        existing.updated_at = now
        await self.db.flush()
        return _result(existing, "updated", operation_id)

    async def _delete(
        self,
        *,
        user: User,
        client_record_id: uuid.UUID,
        client_updated_at: datetime,
        operation_id: str,
    ) -> SyncResult:
        existing = await self.transactions.get_for_user(
            user_id=user.id,
            client_record_id=client_record_id,
        )
        if existing is None:
            return SyncResult(
                operation_id=operation_id,
                client_record_id=client_record_id,
                status="unchanged",
                server_updated_at=utc_now(),
            )

        freshness = _compare_timestamps(
            client_updated_at,
            existing.client_updated_at,
        )
        if freshness < 0:
            return _result(existing, "conflict", operation_id)
        if freshness == 0 and existing.deleted_at is not None:
            return _result(existing, "unchanged", operation_id)
        if freshness == 0:
            return _result(existing, "conflict", operation_id)

        now = utc_now()
        existing.client_updated_at = client_updated_at
        existing.deleted_at = now
        existing.updated_at = now
        await self.db.flush()
        return _result(existing, "deleted", operation_id)


def _installation_hash(installation_id: str) -> str:
    return privacy_hash(f"installation:{installation_id}")


def _payload_values(payload: TransactionSyncPayload) -> dict[str, object]:
    return {
        "client_record_id": payload.client_record_id,
        "transaction_type": payload.transaction_type,
        "amount_in_minor": payload.amount_in_minor,
        "category": payload.category,
        "transaction_date": payload.transaction_date,
        "merchant_name": payload.merchant_name,
        "source": payload.source,
        "raw_ocr_text": payload.raw_ocr_text,
        "note": payload.note,
        "client_created_at": payload.client_created_at,
        "client_updated_at": payload.client_updated_at,
    }


def _matches_payload(
    transaction: CloudTransaction,
    payload: TransactionSyncPayload,
) -> bool:
    for field, value in _payload_values(payload).items():
        stored = getattr(transaction, field)
        if isinstance(value, datetime) and isinstance(stored, datetime):
            if _as_utc(stored) != _as_utc(value):
                return False
        elif stored != value:
            return False
    return True


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _compare_timestamps(left: datetime, right: datetime) -> int:
    left_utc = _as_utc(left)
    right_utc = _as_utc(right)
    return (left_utc > right_utc) - (left_utc < right_utc)


def _result(
    transaction: CloudTransaction,
    status: Literal["created", "updated", "unchanged", "deleted", "conflict"],
    operation_id: str | None,
) -> SyncResult:
    return SyncResult(
        operation_id=operation_id,
        client_record_id=transaction.client_record_id,
        status=status,
        server_updated_at=_as_utc(transaction.updated_at),
    )


def _serialize_transaction(transaction: CloudTransaction) -> SyncedTransaction:
    return SyncedTransaction(
        client_record_id=transaction.client_record_id,
        transaction_type=transaction.transaction_type,
        amount_in_minor=transaction.amount_in_minor,
        category=transaction.category,
        transaction_date=_as_utc(transaction.transaction_date),
        merchant_name=transaction.merchant_name,
        source=transaction.source,
        raw_ocr_text=transaction.raw_ocr_text,
        note=transaction.note,
        client_created_at=_as_utc(transaction.client_created_at),
        client_updated_at=_as_utc(transaction.client_updated_at),
        server_updated_at=_as_utc(transaction.updated_at),
        deleted_at=(
            _as_utc(transaction.deleted_at)
            if transaction.deleted_at is not None
            else None
        ),
    )


def encode_cursor(updated_at: datetime, record_id: uuid.UUID) -> str:
    payload = json.dumps(
        {"updated_at": _as_utc(updated_at).isoformat(), "id": str(record_id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def decode_cursor(cursor: str | None) -> tuple[datetime | None, uuid.UUID | None]:
    if cursor is None:
        return None, None
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        data = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        updated_at = _as_utc(datetime.fromisoformat(data["updated_at"]))
        record_id = uuid.UUID(data["id"])
    except (
        binascii.Error,
        KeyError,
        TypeError,
        ValueError,
        UnicodeDecodeError,
        json.JSONDecodeError,
    ):
        raise InvalidSyncCursor("Invalid sync cursor") from None
    return updated_at, record_id
