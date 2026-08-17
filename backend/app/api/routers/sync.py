import hashlib
import json
import uuid
from datetime import UTC, datetime
from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response, status
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    get_debt_summary_cache,
    require_group_member,
)
from app.api.routers.groups import create_group_expense
from app.api.routers.settlements import create_settlement
from app.core.database import get_db_session
from app.group_schemas import GroupExpenseCreateRequest, ItemizedExpenseCreateRequest
from app.models.group import Group, GroupMember, GroupRole
from app.models.group_expense import (
    ExpenseShare,
    ExpenseShareStatus,
    ExpenseSplitType,
    GroupExpense,
)
from app.models.group_sync_operation import GroupSyncOperation
from app.models.user import User
from app.repositories.group_expenses import GroupExpenseRepository
from app.services.debt_summary_cache import DebtSummaryCache
from app.services.group_expense_service import GroupExpenseService
from app.services.sync_service import (
    ClaimIdempotencyConflict,
    InvalidSyncCursor,
    SyncService,
)
from app.settlement_schemas import SettlementCreateRequest
from app.sync_schemas import (
    ClaimRequest,
    ClaimResponse,
    PullResponse,
    PushRequest,
    PushResponse,
)

router = APIRouter(prefix="/api/v1/sync", tags=["sync"])


class GroupPushRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    operation_type: Literal[
        "groupExpenseCreate",
        "groupExpenseUpdate",
        "groupExpenseDelete",
        "expenseShareCreate",
        "expenseShareUpdate",
        "expenseShareDelete",
        "settlementCreate",
    ]
    group_id: uuid.UUID
    client_record_id: uuid.UUID
    owner_key: str = Field(pattern=r"^user:[0-9a-fA-F-]{36}$")
    sync_state: Literal["pending", "pendingDelete"]
    payload: dict[str, Any]
    sync_payload: dict[str, Any] | None = None

    @model_validator(mode="after")
    def validate_sync_state(self) -> "GroupPushRequest":
        is_delete = self.operation_type in {
            "groupExpenseDelete",
            "expenseShareDelete",
        }
        expected_state = "pendingDelete" if is_delete else "pending"
        if self.sync_state != expected_state:
            raise ValueError(
                f"{self.operation_type} requires sync_state={expected_state}"
            )
        return self


class GroupPushResponse(BaseModel):
    operation_id: uuid.UUID
    status: Literal["accepted", "duplicate"]


class ExpenseSharePushPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    expense_id: uuid.UUID
    user_id: uuid.UUID
    amount_in_minor: int | None = Field(default=None, ge=0)
    status: ExpenseShareStatus | None = None
    settled_at: datetime | None = None
    expected_expense_updated_at: datetime | None = None


class GroupExpenseShareSnapshot(BaseModel):
    model_config = ConfigDict(extra="ignore")

    user_id: uuid.UUID
    amount_in_minor: int = Field(ge=0)


class GroupExpenseUpdatePushPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: uuid.UUID
    group_id: uuid.UUID
    receipt_id: uuid.UUID | None = None
    payer_user_id: uuid.UUID
    title: str = Field(min_length=1, max_length=255)
    note: str | None = None
    expense_date: datetime
    total_amount_in_minor: int = Field(gt=0)
    currency: str = Field(min_length=3, max_length=3)
    split_type: Literal["equal", "percentage", "fixed_amount", "itemized"]
    shares: list[GroupExpenseShareSnapshot] = Field(min_length=1)
    expected_updated_at: datetime | None = None

    @field_validator("title", mode="before")
    @classmethod
    def normalize_title(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.strip().upper()


class GroupExpenseDeletePushPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    group_id: uuid.UUID
    expense_id: uuid.UUID
    expected_updated_at: datetime | None = None


def _group_sync_conflict(code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={"code": code, "message": message},
    )


def _share_request_hash(operation_type: str, body: dict[str, Any]) -> str:
    canonical = json.dumps(
        {"operation_type": operation_type, "payload": body},
        sort_keys=True,
        separators=(",", ":"),
        default=str,
    )
    return hashlib.sha256(canonical.encode()).hexdigest()


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _timestamps_match(left: datetime, right: datetime) -> bool:
    return _as_utc(left) == _as_utc(right)


def _require_expense_mutation_permission(
    *,
    expense: GroupExpense,
    membership: GroupMember,
    user: User,
) -> None:
    if expense.created_by_id == user.id or membership.role in {
        GroupRole.owner,
        GroupRole.admin,
    }:
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={
            "code": "group_forbidden",
            "message": "Bu masrafı yalnız oluşturan kullanıcı veya grup yöneticisi değiştirebilir.",
        },
    )


async def _get_group_mutation_receipt(
    *,
    operation: GroupPushRequest,
    request_hash: str,
    user: User,
    db: AsyncSession,
) -> GroupSyncOperation | None:
    receipt = await db.scalar(
        select(GroupSyncOperation).where(
            GroupSyncOperation.actor_user_id == user.id,
            GroupSyncOperation.client_record_id == operation.client_record_id,
        )
    )
    if receipt is not None and (
        receipt.group_id != operation.group_id
        or receipt.operation_type != operation.operation_type
        or receipt.request_hash != request_hash
    ):
        raise _group_sync_conflict(
            "idempotency_conflict",
            "Aynı clientRecordId daha önce farklı bir işlem için kullanıldı.",
        )
    return receipt


async def _push_group_expense_mutation(
    *,
    operation: GroupPushRequest,
    body: dict[str, Any],
    membership: GroupMember,
    user: User,
    db: AsyncSession,
) -> bool:
    request_hash = _share_request_hash(operation.operation_type, body)
    receipt = await _get_group_mutation_receipt(
        operation=operation,
        request_hash=request_hash,
        user=user,
        db=db,
    )
    if receipt is not None:
        return True

    if operation.operation_type == "groupExpenseUpdate":
        payload = GroupExpenseUpdatePushPayload.model_validate(body)
        expense_id = payload.id
        payload_group_id = payload.group_id
        expected_updated_at = payload.expected_updated_at
    else:
        payload = GroupExpenseDeletePushPayload.model_validate(body)
        expense_id = payload.expense_id
        payload_group_id = payload.group_id
        expected_updated_at = payload.expected_updated_at

    if payload_group_id != operation.group_id:
        raise _group_sync_conflict(
            "version_mismatch", "Operasyon grubu masraf kaydıyla eşleşmiyor."
        )

    expense = await GroupExpenseRepository(db).get_by_id(
        expense_id,
        include_deleted=True,
        for_update=True,
    )
    if expense is None or expense.group_id != operation.group_id:
        raise _group_sync_conflict(
            "version_mismatch", "Değiştirilecek masraf sunucuda mevcut değil."
        )
    _require_expense_mutation_permission(
        expense=expense,
        membership=membership,
        user=user,
    )
    if expense.deleted_at is not None:
        raise _group_sync_conflict(
            "record_soft_deleted", "Silinmiş bir masraf değiştirilemez."
        )
    if expected_updated_at is not None and not _timestamps_match(
        expense.updated_at,
        expected_updated_at,
    ):
        raise _group_sync_conflict(
            "version_mismatch", "Masraf başka bir cihazda güncellendi."
        )

    financially_locked = await GroupExpenseService(db).is_financially_locked(expense)

    if operation.operation_type == "groupExpenseDelete":
        if financially_locked:
            raise _group_sync_conflict(
                "expense_financially_locked",
                "Borç kapatma sonrasında finansal masraf silinemez.",
            )
        now = datetime.now(UTC)
        expense.deleted_at = now
        expense.updated_at = now
    else:
        assert isinstance(payload, GroupExpenseUpdatePushPayload)
        normalized_currency = payload.currency.strip().upper()
        incoming_shares = {
            share.user_id: share.amount_in_minor for share in payload.shares
        }
        if len(incoming_shares) != len(payload.shares):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={
                    "code": "invalid_split",
                    "message": "Masraf payları benzersiz olmalıdır.",
                },
            )
        if sum(incoming_shares.values()) != payload.total_amount_in_minor:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={
                    "code": "invalid_split_total",
                    "message": "Masraf payları toplam tutarla eşleşmelidir.",
                },
            )

        group = await db.get(Group, operation.group_id)
        if group is None or normalized_currency != group.currency.upper():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={
                    "code": "currency_mismatch",
                    "message": "Masraf para birimi grupla eşleşmelidir.",
                },
            )
        required_member_ids = {payload.payer_user_id, *incoming_shares.keys()}
        active_member_ids = set(
            (
                await db.scalars(
                    select(GroupMember.user_id).where(
                        GroupMember.group_id == operation.group_id,
                        GroupMember.user_id.in_(tuple(required_member_ids)),
                        GroupMember.left_at.is_(None),
                    )
                )
            ).all()
        )
        if required_member_ids - active_member_ids:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={
                    "code": "member_not_found",
                    "message": "Masraf paylarında aktif olmayan grup üyesi var.",
                },
            )

        stored_shares = {
            share.user_id: share.amount_in_minor for share in expense.shares
        }
        financial_changed = (
            expense.receipt_id != payload.receipt_id
            or expense.payer_user_id != payload.payer_user_id
            or expense.total_amount_in_minor != payload.total_amount_in_minor
            or expense.currency.upper() != normalized_currency
            or expense.split_type.value != payload.split_type
            or stored_shares != incoming_shares
        )
        if financially_locked and financial_changed:
            raise _group_sync_conflict(
                "expense_financially_locked",
                "Borç kapatma sonrasında masrafın finansal alanları değiştirilemez.",
            )
        if financial_changed and (
            expense.split_type.value == "itemized" or payload.split_type == "itemized"
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={
                    "code": "itemized_update_not_supported",
                    "message": "Itemized masrafın finansal alanları çevrimdışı güncellenemez.",
                },
            )

        expense.title = payload.title.strip()
        expense.note = payload.note
        expense.expense_date = payload.expense_date
        if financial_changed:
            expense.receipt_id = payload.receipt_id
            expense.payer_user_id = payload.payer_user_id
            expense.total_amount_in_minor = payload.total_amount_in_minor
            expense.currency = normalized_currency
            expense.split_type = ExpenseSplitType(payload.split_type)
            existing_shares = {share.user_id: share for share in expense.shares}
            replacement_shares: list[ExpenseShare] = []
            for user_id, amount in sorted(
                incoming_shares.items(),
                key=lambda item: str(item[0]),
            ):
                share = existing_shares.get(user_id)
                if share is None:
                    share = ExpenseShare(user_id=user_id, amount_in_minor=amount)
                else:
                    share.amount_in_minor = amount
                replacement_shares.append(share)
            expense.shares = replacement_shares
            expense.line_item_assignments = []
            expense.extra_amounts = []
        expense.updated_at = datetime.now(UTC)

    db.add(
        GroupSyncOperation(
            group_id=operation.group_id,
            actor_user_id=user.id,
            client_record_id=operation.client_record_id,
            operation_type=operation.operation_type,
            request_hash=request_hash,
        )
    )
    await db.commit()
    return False


async def _push_expense_share(
    *,
    operation: GroupPushRequest,
    body: dict[str, Any],
    user: User,
    db: AsyncSession,
) -> bool:
    request_hash = _share_request_hash(operation.operation_type, body)
    receipt = await db.scalar(
        select(GroupSyncOperation).where(
            GroupSyncOperation.actor_user_id == user.id,
            GroupSyncOperation.client_record_id == operation.client_record_id,
        )
    )
    if receipt is not None:
        if (
            receipt.group_id != operation.group_id
            or receipt.operation_type != operation.operation_type
            or receipt.request_hash != request_hash
        ):
            raise _group_sync_conflict(
                "idempotency_conflict",
                "Aynı clientRecordId daha önce farklı bir işlem için kullanıldı.",
            )
        return True

    payload = ExpenseSharePushPayload.model_validate(body)
    expense = await db.scalar(
        select(GroupExpense).where(GroupExpense.id == payload.expense_id)
    )
    if expense is None or expense.group_id != operation.group_id:
        raise _group_sync_conflict(
            "version_mismatch", "Payın bağlı olduğu masraf artık mevcut değil."
        )
    if expense.deleted_at is not None:
        raise _group_sync_conflict(
            "record_soft_deleted", "Silinmiş bir masrafın payı değiştirilemez."
        )
    if (
        payload.expected_expense_updated_at is not None
        and expense.updated_at != payload.expected_expense_updated_at
    ):
        raise _group_sync_conflict(
            "version_mismatch", "Masraf başka bir cihazda güncellendi."
        )

    member = await db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == operation.group_id,
            GroupMember.user_id == payload.user_id,
            GroupMember.left_at.is_(None),
        )
    )
    if member is None:
        raise _group_sync_conflict(
            "version_mismatch", "Pay sahibi artık grubun aktif bir üyesi değil."
        )

    share = await db.get(ExpenseShare, (payload.expense_id, payload.user_id))
    if share is not None and (
        share.status != ExpenseShareStatus.open or share.settled_at is not None
    ):
        raise _group_sync_conflict(
            "expense_financially_locked",
            "Borç kapatma uygulanmış bir masraf payı değiştirilemez.",
        )

    if operation.operation_type == "expenseShareCreate":
        if share is not None:
            raise _group_sync_conflict(
                "version_mismatch", "Masraf payı sunucuda zaten mevcut."
            )
        if payload.amount_in_minor is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={"code": "invalid_share", "message": "Pay tutarı zorunludur."},
            )
        share = ExpenseShare(
            expense_id=payload.expense_id,
            user_id=payload.user_id,
            amount_in_minor=payload.amount_in_minor,
            status=payload.status or ExpenseShareStatus.open,
            settled_at=payload.settled_at,
        )
        db.add(share)
    elif operation.operation_type == "expenseShareUpdate":
        if share is None:
            raise _group_sync_conflict(
                "version_mismatch", "Güncellenecek masraf payı mevcut değil."
            )
        if payload.amount_in_minor is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={"code": "invalid_share", "message": "Pay tutarı zorunludur."},
            )
        share.amount_in_minor = payload.amount_in_minor
        share.status = payload.status or share.status
        share.settled_at = payload.settled_at
    else:
        if share is None:
            raise _group_sync_conflict(
                "version_mismatch", "Silinecek masraf payı mevcut değil."
            )
        await db.delete(share)

    db.add(
        GroupSyncOperation(
            group_id=operation.group_id,
            actor_user_id=user.id,
            client_record_id=operation.client_record_id,
            operation_type=operation.operation_type,
            request_hash=request_hash,
        )
    )
    await db.commit()
    return False


@router.post("/groups/push", response_model=GroupPushResponse)
async def push_group_operation(
    payload: GroupPushRequest,
    response: Response,
    idempotency_key: Annotated[
        str,
        Header(alias="Idempotency-Key", min_length=8, max_length=128),
    ],
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
    debt_cache: DebtSummaryCache = Depends(get_debt_summary_cache),
) -> GroupPushResponse:
    if idempotency_key != str(payload.client_record_id):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail={
                "code": "tracking_id_mismatch",
                "message": "Sync tracking ID uyuşmuyor.",
            },
        )
    if payload.owner_key != f"user:{user.id}":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "owner_scope_mismatch",
                "message": "Sync kaydı aktif kullanıcıya ait değil.",
            },
        )

    membership = await require_group_member(payload.group_id, user, db)
    resource_response = Response()
    body = payload.sync_payload or payload.payload
    if payload.operation_type == "groupExpenseCreate":
        split = body.get("split")
        request = (
            ItemizedExpenseCreateRequest.model_validate(body)
            if isinstance(split, dict) and split.get("type") == "itemized"
            else GroupExpenseCreateRequest.model_validate(body)
        )
        await create_group_expense(
            group_id=payload.group_id,
            payload=request,
            response=resource_response,
            actor_membership=membership,
            idempotency_key=idempotency_key,
            db=db,
            debt_cache=debt_cache,
        )
    elif payload.operation_type in {"groupExpenseUpdate", "groupExpenseDelete"}:
        replayed = await _push_group_expense_mutation(
            operation=payload,
            body=body,
            membership=membership,
            user=user,
            db=db,
        )
        await debt_cache.invalidate_best_effort(payload.group_id)
        if replayed:
            response.headers["Idempotency-Replayed"] = "true"
        return GroupPushResponse(
            operation_id=payload.client_record_id,
            status="duplicate" if replayed else "accepted",
        )
    elif payload.operation_type == "settlementCreate":
        request = SettlementCreateRequest.model_validate(body)
        await create_settlement(
            group_id=payload.group_id,
            payload=request,
            response=resource_response,
            actor_membership=membership,
            idempotency_key=idempotency_key,
            db=db,
            debt_cache=debt_cache,
        )
    else:
        replayed = await _push_expense_share(
            operation=payload,
            body=body,
            user=user,
            db=db,
        )
        if replayed:
            response.headers["Idempotency-Replayed"] = "true"
        return GroupPushResponse(
            operation_id=payload.client_record_id,
            status="duplicate" if replayed else "accepted",
        )

    replayed = resource_response.headers.get("Idempotency-Replayed") == "true"
    if replayed:
        response.headers["Idempotency-Replayed"] = "true"
    return GroupPushResponse(
        operation_id=payload.client_record_id,
        status="duplicate" if replayed else "accepted",
    )


@router.post("/claim", response_model=ClaimResponse)
async def claim_transactions(
    payload: ClaimRequest,
    idempotency_key: Annotated[
        str,
        Header(alias="Idempotency-Key", min_length=8, max_length=128),
    ],
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ClaimResponse:
    try:
        return await SyncService(db).claim(
            user=user,
            idempotency_key=idempotency_key,
            installation_id=payload.installation_id,
            transactions=payload.transactions,
        )
    except ClaimIdempotencyConflict:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Idempotency-Key was already used for a different request.",
        ) from None


@router.post("/push", response_model=PushResponse)
async def push_transactions(
    payload: PushRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PushResponse:
    return await SyncService(db).push(
        user=user,
        installation_id=payload.installation_id,
        operations=payload.operations,
    )


@router.get("/pull", response_model=PullResponse)
async def pull_transactions(
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PullResponse:
    try:
        return await SyncService(db).pull(
            user=user,
            cursor=cursor,
            limit=limit,
        )
    except InvalidSyncCursor:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid sync cursor.",
        ) from None
