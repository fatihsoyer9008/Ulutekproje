import base64
import binascii
import hashlib
import json
import uuid
from datetime import UTC, datetime
from typing import Literal

from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import privacy_hash, utc_now
from app.models.cloud_receipt import CloudReceipt
from app.models.cloud_transaction import CloudTransaction
from app.models.user import User
from app.repositories.cloud_receipts import CloudReceiptRepository
from app.repositories.cloud_transactions import CloudTransactionRepository
from app.repositories.sync_claim_requests import SyncClaimRequestRepository
from app.sync_schemas import (
    ClaimResponse,
    ClaimResult,
    PullResponse,
    PushOperation,
    PushResponse,
    SyncedCloudReceipt,
    SyncedTransaction,
    SyncResult,
    TransactionSyncPayload,
)


class InvalidSyncCursor(ValueError):
    pass


class ClaimIdempotencyConflict(ValueError):
    pass


class SyncService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.transactions = CloudTransactionRepository(db)
        self.receipts = CloudReceiptRepository(db)
        self.claim_requests = SyncClaimRequestRepository(db)

    async def claim(
        self,
        *,
        user: User,
        idempotency_key: str,
        installation_id: str,
        transactions: list[object],
    ) -> ClaimResponse:
        key_hash = privacy_hash(f"sync-claim:{idempotency_key}")
        request_hash = _claim_request_hash(installation_id, transactions)
        claim_request = await self.claim_requests.try_create(
            user_id=user.id,
            idempotency_key_hash=key_hash,
            request_hash=request_hash,
        )
        if claim_request is None:
            previous = await self.claim_requests.get(
                user_id=user.id,
                idempotency_key_hash=key_hash,
            )
            if previous is None or previous.response_json is None:
                raise RuntimeError("Claim idempotency record is unavailable")
            if previous.request_hash != request_hash:
                raise ClaimIdempotencyConflict
            return ClaimResponse.model_validate(previous.response_json)

        installation_hash = _installation_hash(installation_id)
        results: list[ClaimResult] = []
        for raw_transaction in transactions:
            try:
                payload = TransactionSyncPayload.model_validate(raw_transaction)
            except ValidationError:
                results.append(
                    ClaimResult(
                        client_record_id=_extract_client_record_id(raw_transaction),
                        status="rejected",
                        error="Invalid transaction payload.",
                    )
                )
                continue

            sync_result = await self._upsert(
                user=user,
                installation_hash=installation_hash,
                payload=payload,
            )
            if sync_result.status in {"created", "updated"}:
                claim_status = "accepted"
                error = None
            elif sync_result.status == "unchanged":
                claim_status = "duplicate"
                error = None
            else:
                claim_status = "rejected"
                error = "A newer or different version already exists."
            results.append(
                ClaimResult(
                    client_record_id=payload.client_record_id,
                    status=claim_status,
                    error=error,
                )
            )

        response = ClaimResponse(owner_key=f"user:{user.id}", results=results)
        claim_request.response_json = response.model_dump(mode="json")
        await self.db.commit()
        return response

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
        receipts_cursor: str | None = None,
        receipts_limit: int = 100,
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

        receipts_after_updated_at, receipts_after_id = decode_cursor(receipts_cursor)
        receipt_records = await self.receipts.list_changes(
            user_id=user.id,
            limit=receipts_limit + 1,
            after_updated_at=receipts_after_updated_at,
            after_id=receipts_after_id,
        )
        receipts_has_more = len(receipt_records) > receipts_limit
        receipts_page = receipt_records[:receipts_limit]
        receipts_next_cursor = (
            encode_cursor(receipts_page[-1].updated_at, receipts_page[-1].id)
            if receipts_page
            else receipts_cursor
        )

        return PullResponse(
            transactions=[_serialize_transaction(item) for item in page],
            next_cursor=next_cursor,
            has_more=has_more,
            cloud_receipts=[
                _serialize_cloud_receipt(item) for item in receipts_page
            ],
            cloud_receipts_next_cursor=receipts_next_cursor,
            cloud_receipts_has_more=receipts_has_more,
        )

    async def _upsert(
        self,
        *,
        user: User,
        installation_hash: str,
        payload: TransactionSyncPayload,
        operation_id: str | None = None,
    ) -> SyncResult:
        now = utc_now()
        insert_values = {
            "id": uuid.uuid4(),
            "user_id": user.id,
            "installation_id_hash": installation_hash,
            "created_at": now,
            "updated_at": now,
            "deleted_at": None,
            **_payload_values(payload),
        }
        created = await self.transactions.try_insert(values=insert_values)
        if created is not None:
            return _result(created, "created", operation_id)

        updated = await self.transactions.update_if_newer(
            user_id=user.id,
            client_record_id=payload.client_record_id,
            client_updated_at=payload.client_updated_at,
            values={
                **_payload_values(payload),
                "installation_id_hash": installation_hash,
                "deleted_at": None,
                "updated_at": now,
            },
        )
        if updated is not None:
            return _result(updated, "updated", operation_id)

        existing = await self.transactions.get_for_user(
            user_id=user.id,
            client_record_id=payload.client_record_id,
        )
        if existing is None:
            raise RuntimeError("Cloud transaction disappeared during upsert")

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

        return _result(existing, "conflict", operation_id)

    async def _delete(
        self,
        *,
        user: User,
        client_record_id: uuid.UUID,
        client_updated_at: datetime,
        operation_id: str,
    ) -> SyncResult:
        now = utc_now()
        deleted = await self.transactions.delete_if_newer(
            user_id=user.id,
            client_record_id=client_record_id,
            client_updated_at=client_updated_at,
            deleted_at=now,
        )
        if deleted is not None:
            return _result(deleted, "deleted", operation_id)

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

        return _result(existing, "conflict", operation_id)


def _installation_hash(installation_id: str) -> str:
    return privacy_hash(f"installation:{installation_id}")


def _claim_request_hash(
    installation_id: str,
    transactions: list[object],
) -> str:
    canonical = json.dumps(
        {"installation_id": installation_id, "transactions": transactions},
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def _extract_client_record_id(raw_transaction: object) -> uuid.UUID | None:
    if not isinstance(raw_transaction, dict):
        return None
    try:
        return uuid.UUID(str(raw_transaction.get("client_record_id")))
    except (AttributeError, TypeError, ValueError):
        return None


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


def _serialize_cloud_receipt(receipt: CloudReceipt) -> SyncedCloudReceipt:
    return SyncedCloudReceipt(
        id=receipt.id,
        client_record_id=receipt.client_record_id,
        merchant_name=receipt.merchant_name,
        total_amount_in_minor=receipt.total_amount_in_minor,
        currency=receipt.currency,
        receipt_date=(
            _as_utc(receipt.receipt_date) if receipt.receipt_date is not None else None
        ),
        category=receipt.category,
        normalized_ocr_text=receipt.normalized_ocr_text,
        raw_ocr_text=receipt.raw_ocr_text,
        is_parse_successful=receipt.is_parse_successful,
        confidence_score=(
            float(receipt.confidence_score)
            if receipt.confidence_score is not None
            else None
        ),
        client_created_at=_as_utc(receipt.client_created_at),
        client_updated_at=_as_utc(receipt.client_updated_at),
        server_updated_at=_as_utc(receipt.updated_at),
        deleted_at=(
            _as_utc(receipt.deleted_at) if receipt.deleted_at is not None else None
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
