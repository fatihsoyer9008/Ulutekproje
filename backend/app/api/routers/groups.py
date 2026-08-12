import hashlib
import json
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    require_group_admin,
    require_group_member,
    require_group_owner,
)
from app.core.config import settings
from app.core.database import get_db_session
from app.group_schemas import (
    ExpenseShareResponse,
    FastSplitType,
    GroupCreateRequest,
    GroupExpenseCreateRequest,
    GroupExpenseEnvelope,
    GroupExpenseResponse,
    GroupMemberCreateRequest,
    GroupMemberEnvelope,
    GroupMemberRoleUpdateRequest,
    GroupResponse,
    GroupsResponse,
    GroupUpdateRequest,
)
from app.models.group import GroupMember
from app.models.group_expense import ExpenseSplitType, GroupExpense
from app.models.user import User
from app.services.group_expense_service import (
    FastSplitValidationError,
    GroupExpenseService,
)
from app.services.group_service import GroupService, GroupServiceError

router = APIRouter(prefix="/api/v1/groups", tags=["groups"])

_EXPENSE_ERRORS = {
    "group_not_found": (404, "Grup bulunamadı."),
    "group_forbidden": (403, "Bu grup için yetkiniz yok."),
    "member_not_found": (422, "Ödeyen ve tüm katılımcılar aktif grup üyesi olmalıdır."),
    "currency_mismatch": (422, "Masraf para birimi grup para birimiyle eşleşmelidir."),
    "invalid_amount": (
        422,
        "Masraf ve pay tutarları geçerli pozitif değerler olmalıdır.",
    ),
    "invalid_split_type": (422, "Split türü EQUAL, PERCENTAGE veya EXACT olmalıdır."),
    "percentage_total_must_be_100": (
        422,
        "Pay yüzdelerinin toplamı tam olarak %100.00 olmalıdır.",
    ),
    "exact_total_must_match_expense": (
        422,
        "Sabit payların toplamı masraf tutarına eşit olmalıdır.",
    ),
    "idempotency_key_reused": (
        409,
        "Idempotency-Key farklı bir istek için daha önce kullanılmış.",
    ),
}


def _expense_response(expense: GroupExpense) -> GroupExpenseEnvelope:
    external_type = {
        ExpenseSplitType.equal: FastSplitType.equal,
        ExpenseSplitType.percentage: FastSplitType.percentage,
        ExpenseSplitType.fixed_amount: FastSplitType.exact,
    }[expense.split_type]
    return GroupExpenseEnvelope(
        expense=GroupExpenseResponse(
            id=expense.id,
            group_id=expense.group_id,
            paid_by_id=expense.payer_user_id,
            created_by_id=expense.created_by_id,
            title=expense.title,
            note=expense.note,
            expense_date=expense.expense_date,
            total_amount_in_minor=expense.total_amount_in_minor,
            currency=expense.currency,
            split_type=external_type,
            shares=[
                ExpenseShareResponse(
                    user_id=s.user_id, amount_in_minor=s.amount_in_minor
                )
                for s in sorted(expense.shares, key=lambda share: str(share.user_id))
            ],
        )
    )


@router.post(
    "/{group_id}/expenses",
    response_model=GroupExpenseEnvelope,
    status_code=status.HTTP_201_CREATED,
)
async def create_group_expense(
    group_id: uuid.UUID,
    payload: GroupExpenseCreateRequest,
    response: Response,
    actor_membership: GroupMember = Depends(require_group_member),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", min_length=1, max_length=255
    ),
    db: AsyncSession = Depends(get_db_session),
) -> GroupExpenseEnvelope:
    request_hash = hashlib.sha256(
        json.dumps(
            payload.model_dump(mode="json"), sort_keys=True, separators=(",", ":")
        ).encode()
    ).hexdigest()
    split_type = {
        FastSplitType.equal: ExpenseSplitType.equal,
        FastSplitType.percentage: ExpenseSplitType.percentage,
        FastSplitType.exact: ExpenseSplitType.fixed_amount,
    }[payload.split_type]
    participants = [
        (
            item.user_id,
            item.percentage
            if payload.split_type is FastSplitType.percentage
            else item.amount_in_minor,
        )
        for item in payload.participants
    ]
    service = GroupExpenseService(db)
    try:
        expense, replayed = await service.create_fast_split(
            group_id=group_id,
            actor_user_id=actor_membership.user_id,
            payer_user_id=payload.paid_by_id,
            title=payload.title,
            note=payload.note,
            expense_date=payload.expense_date,
            total_amount_in_minor=payload.total_amount_in_minor,
            currency=payload.currency,
            split_type=split_type,
            participants=participants,
            idempotency_key=idempotency_key,
            idempotency_request_hash=request_hash,
        )
        await db.commit()
    except FastSplitValidationError as error:
        code, message = _EXPENSE_ERRORS[error.code]
        raise HTTPException(
            code, detail={"code": error.code, "message": message}
        ) from None
    except IntegrityError:
        await db.rollback()
        if not idempotency_key:
            raise
        expense = await service.repository.get_by_idempotency_key(
            group_id=group_id,
            created_by_id=actor_membership.user_id,
            key=idempotency_key,
        )
        if expense is None or expense.idempotency_request_hash != request_hash:
            message = _EXPENSE_ERRORS["idempotency_key_reused"][1]
            raise HTTPException(
                409, detail={"code": "idempotency_key_reused", "message": message}
            ) from None
        replayed = True
    if replayed:
        response.status_code = status.HTTP_200_OK
        response.headers["Idempotency-Replayed"] = "true"
    return _expense_response(expense)


_ERRORS = {
    "group_not_found": (
        status.HTTP_404_NOT_FOUND,
        "Grup bulunamadı.",
    ),
    "group_forbidden": (
        status.HTTP_403_FORBIDDEN,
        "Bu grup için yetkiniz yok.",
    ),
    "user_not_found": (status.HTTP_404_NOT_FOUND, "Kullanıcı bulunamadı."),
    "member_not_found": (status.HTTP_404_NOT_FOUND, "Grup üyesi bulunamadı."),
    "member_already_exists": (
        status.HTTP_409_CONFLICT,
        "Kullanıcı zaten grubun üyesi.",
    ),
    "last_owner_required": (
        status.HTTP_409_CONFLICT,
        "Son owner gruptan ayrılamaz. Önce owner devri yapmalı veya başka bir owner atamalısınız.",
    ),
}


def _raise_group_error(error: GroupServiceError) -> None:
    status_code, message = _ERRORS[error.code]
    raise HTTPException(
        status_code=status_code,
        detail={"code": error.code, "message": message},
    ) from None


def require_direct_member_add_enabled() -> None:
    """Hide the local/mock member-add route in production."""
    if settings.app_env.casefold() == "production":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "group_not_found", "message": "Grup bulunamadı."},
        )


@router.post(
    "",
    response_model=GroupResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_group(
    payload: GroupCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> GroupResponse:
    group = await GroupService(db).create(
        actor_user_id=user.id,
        name=payload.name,
        description=payload.description,
        currency=payload.currency,
    )
    return GroupResponse(group=group)


@router.get("", response_model=GroupsResponse)
async def list_groups(
    include_archived: bool = Query(default=False),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> GroupsResponse:
    groups = await GroupService(db).list_for_user(
        actor_user_id=user.id,
        include_archived=include_archived,
    )
    return GroupsResponse(groups=groups)


@router.get("/{group_id}", response_model=GroupResponse)
async def get_group(
    group_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> GroupResponse:
    service = GroupService(db)
    try:
        group = await service.get_detail(
            group_id=_parse_group_id(group_id),
            actor_user_id=user.id,
        )
    except GroupServiceError as error:
        _raise_group_error(error)
    return GroupResponse(group=group)


@router.patch("/{group_id}", response_model=GroupResponse)
async def update_group(
    group_id: str,
    payload: GroupUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> GroupResponse:
    service = GroupService(db)
    try:
        group = await service.update(
            group_id=_parse_group_id(group_id),
            actor_user_id=user.id,
            changes=payload.model_dump(
                include=payload.model_fields_set,
            ),
        )
    except GroupServiceError as error:
        _raise_group_error(error)
    return GroupResponse(group=group)


@router.delete("/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def archive_group(
    group_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> Response:
    service = GroupService(db)
    try:
        await service.archive(
            group_id=_parse_group_id(group_id),
            actor_user_id=user.id,
        )
    except GroupServiceError as error:
        _raise_group_error(error)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{group_id}/members",
    response_model=GroupMemberEnvelope,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_direct_member_add_enabled)],
)
async def add_group_member(
    group_id: uuid.UUID,
    payload: GroupMemberCreateRequest,
    actor_membership: GroupMember = Depends(require_group_admin),
    db: AsyncSession = Depends(get_db_session),
) -> GroupMemberEnvelope:
    try:
        member = await GroupService(db).add_member(
            group_id=group_id,
            actor_user_id=actor_membership.user_id,
            user_id=payload.user_id,
            role=payload.role,
        )
    except GroupServiceError as error:
        _raise_group_error(error)
    return GroupMemberEnvelope(member=member)


@router.delete(
    "/{group_id}/members/me",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def leave_group(
    group_id: uuid.UUID,
    actor_membership: GroupMember = Depends(require_group_member),
    db: AsyncSession = Depends(get_db_session),
) -> Response:
    try:
        await GroupService(db).remove_member(
            group_id=group_id,
            actor_user_id=actor_membership.user_id,
            user_id=actor_membership.user_id,
        )
    except GroupServiceError as error:
        _raise_group_error(error)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/{group_id}/members/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_group_member(
    group_id: uuid.UUID,
    user_id: uuid.UUID,
    actor_membership: GroupMember = Depends(require_group_member),
    db: AsyncSession = Depends(get_db_session),
) -> Response:
    try:
        await GroupService(db).remove_member(
            group_id=group_id,
            actor_user_id=actor_membership.user_id,
            user_id=user_id,
        )
    except GroupServiceError as error:
        _raise_group_error(error)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch(
    "/{group_id}/members/{user_id}",
    response_model=GroupMemberEnvelope,
)
async def update_group_member_role(
    group_id: uuid.UUID,
    user_id: uuid.UUID,
    payload: GroupMemberRoleUpdateRequest,
    actor_membership: GroupMember = Depends(require_group_owner),
    db: AsyncSession = Depends(get_db_session),
) -> GroupMemberEnvelope:
    try:
        member = await GroupService(db).update_member_role(
            group_id=group_id,
            actor_user_id=actor_membership.user_id,
            user_id=user_id,
            role=payload.role,
        )
    except GroupServiceError as error:
        _raise_group_error(error)
    return GroupMemberEnvelope(member=member)


def _parse_group_id(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "group_not_found", "message": "Grup bulunamadı."},
        ) from None
