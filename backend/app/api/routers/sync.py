import hashlib
import json
import uuid
from datetime import datetime
from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response, status
from pydantic import BaseModel, ConfigDict, Field
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
from app.models.group import GroupMember
from app.models.group_expense import (
    ExpenseShare,
    ExpenseShareStatus,
    GroupExpense,
)
from app.models.group_sync_operation import GroupSyncOperation
from app.models.user import User
from app.services.debt_summary_cache import DebtSummaryCache
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
            detail={"code": "tracking_id_mismatch", "message": "Sync tracking ID uyuşmuyor."},
        )
    if payload.owner_key != f"user:{user.id}":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "owner_scope_mismatch", "message": "Sync kaydı aktif kullanıcıya ait değil."},
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
