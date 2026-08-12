import hashlib
import json
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response, status
from sqlalchemy import select
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
    GroupExpensesResponse,
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
    ItemizedExpenseValidationError,
    LineItemAssignmentInput,
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
    "receipt_not_synced": (409, "Fiş henüz buluta senkronize edilmemiş."),
    "invalid_request": (422, "Kalem bazlı bölüştürme isteği geçersiz."),
    "invalid_split_total": (422, "Payların toplamı fiş toplamıyla eşleşmelidir."),
    "unassigned_line_items": (422, "Atanmayan fiş ürünleri bulunuyor."),
}


async def _expense_response(
    expense: GroupExpense, db: AsyncSession
) -> GroupExpenseEnvelope:
    user_ids = [share.user_id for share in expense.shares]
    names = dict(
        (
            await db.execute(
                select(User.id, User.display_name).where(User.id.in_(user_ids))
            )
        ).all()
    )
    return GroupExpenseEnvelope(
        expense=GroupExpenseResponse(
            id=expense.id,
            group_id=expense.group_id,
            receipt_id=expense.receipt_id,
            payer_user_id=expense.payer_user_id,
            created_by=expense.created_by_id,
            title=expense.title,
            note=expense.note,
            expense_date=expense.expense_date,
            total_amount_in_minor=expense.total_amount_in_minor,
            currency=expense.currency,
            split_type=expense.split_type.value,
            is_financially_locked=False,
            shares=[
                ExpenseShareResponse(
                    expense_id=expense.id,
                    user_id=s.user_id,
                    display_name=names.get(s.user_id) or "Silinmiş kullanıcı",
                    amount_in_minor=s.amount_in_minor,
                    status=s.status.value,
                    settled_at=s.settled_at,
                )
                for s in sorted(expense.shares, key=lambda share: str(share.user_id))
            ],
            line_item_assignments=[
                {
                    "expense_id": assignment.expense_id,
                    "receipt_line_item_id": assignment.receipt_line_item_id,
                    "user_id": assignment.user_id,
                    "amount_in_minor": assignment.amount_in_minor,
                    "quantity_share_milli": assignment.quantity_share_milli,
                }
                for assignment in sorted(
                    expense.__dict__.get("line_item_assignments", []),
                    key=lambda item: (
                        str(item.receipt_line_item_id),
                        str(item.user_id),
                    ),
                )
            ],
            created_at=expense.created_at,
            updated_at=expense.updated_at,
            deleted_at=expense.deleted_at,
        )
    )


async def _expense_value(
    expense: GroupExpense, db: AsyncSession
) -> GroupExpenseResponse:
    return (await _expense_response(expense, db)).expense


def _is_idempotency_collision(error: IntegrityError) -> bool:
    current: BaseException | None = error
    while current is not None:
        if getattr(current, "constraint_name", None) == "uq_group_expenses_idempotency":
            return True
        current = current.__cause__
    return "uq_group_expenses_idempotency" in str(error)


@router.get("/{group_id}/expenses", response_model=GroupExpensesResponse)
async def list_group_expenses(
    group_id: uuid.UUID,
    actor_membership: GroupMember = Depends(require_group_member),
    db: AsyncSession = Depends(get_db_session),
) -> GroupExpensesResponse:
    del actor_membership
    expenses = await GroupExpenseService(db).repository.list_for_group(group_id)
    return GroupExpensesResponse(
        expenses=[await _expense_value(expense, db) for expense in expenses]
    )


@router.get("/{group_id}/expenses/{expense_id}", response_model=GroupExpenseEnvelope)
async def get_group_expense(
    group_id: uuid.UUID,
    expense_id: uuid.UUID,
    actor_membership: GroupMember = Depends(require_group_member),
    db: AsyncSession = Depends(get_db_session),
) -> GroupExpenseEnvelope:
    del actor_membership
    expense = await GroupExpenseService(db).repository.get_by_id(expense_id)
    if expense is None or expense.group_id != group_id:
        raise HTTPException(
            404,
            detail={"code": "expense_not_found", "message": "Masraf bulunamadı."},
        )
    return await _expense_response(expense, db)


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
    idempotency_key: str = Header(
        alias="Idempotency-Key", min_length=8, max_length=128
    ),
    db: AsyncSession = Depends(get_db_session),
) -> GroupExpenseEnvelope:
    actor_user_id = actor_membership.user_id
    request_hash = hashlib.sha256(
        json.dumps(
            payload.model_dump(mode="json"), sort_keys=True, separators=(",", ":")
        ).encode()
    ).hexdigest()
    service = GroupExpenseService(db)
    if payload.split.type is FastSplitType.itemized:
        assert payload.receipt_id is not None
        assignments = [
            LineItemAssignmentInput(
                receipt_line_item_id=line_item.receipt_line_item_id,
                user_id=share.user_id,
                amount_in_minor=share.amount_in_minor,
                quantity_share_milli=share.quantity_share_milli,
            )
            for line_item in payload.split.line_items or []
            for share in line_item.shares
        ]
        try:
            expense, replayed = await service.create_itemized(
                group_id=group_id,
                receipt_id=payload.receipt_id,
                actor_user_id=actor_user_id,
                payer_user_id=payload.payer_user_id,
                title=payload.title,
                note=payload.note,
                expense_date=payload.expense_date,
                total_amount_in_minor=payload.total_amount_in_minor,
                currency=payload.currency,
                assignments=assignments,
                extra_amount_shares=[
                    (share.user_id, share.amount_in_minor)
                    for share in payload.split.extra_amount_shares or []
                ],
                idempotency_key=idempotency_key,
                idempotency_request_hash=request_hash,
            )
            await db.commit()
        except ItemizedExpenseValidationError as error:
            code, message = _EXPENSE_ERRORS[error.code]
            public_code = (
                "idempotency_conflict"
                if error.code == "idempotency_key_reused"
                else error.code
            )
            detail: dict[str, object] = {"code": public_code, "message": message}
            if error.unassigned_receipt_line_item_ids:
                detail["unassigned_receipt_line_item_ids"] = [
                    str(item_id) for item_id in error.unassigned_receipt_line_item_ids
                ]
            raise HTTPException(code, detail=detail) from None
        except IntegrityError as error:
            await db.rollback()
            if not _is_idempotency_collision(error):
                raise
            expense = await service.repository.get_by_idempotency_key(
                group_id=group_id,
                created_by_id=actor_user_id,
                key=idempotency_key,
            )
            if expense is None or expense.idempotency_request_hash != request_hash:
                message = _EXPENSE_ERRORS["idempotency_key_reused"][1]
                raise HTTPException(
                    409,
                    detail={"code": "idempotency_conflict", "message": message},
                ) from None
            replayed = True
        if replayed:
            response.status_code = status.HTTP_200_OK
            response.headers["Idempotency-Replayed"] = "true"
        return await _expense_response(expense, db)

    split_type = {
        FastSplitType.equal: ExpenseSplitType.equal,
        FastSplitType.percentage: ExpenseSplitType.percentage,
        FastSplitType.fixed_amount: ExpenseSplitType.fixed_amount,
    }[payload.split.type]
    if payload.split.type is FastSplitType.equal:
        participants = [(user_id, None) for user_id in payload.split.member_ids or []]
    else:
        participants = [
            (
                item.user_id,
                item.percentage_basis_points
                if payload.split.type is FastSplitType.percentage
                else item.amount_in_minor,
            )
            for item in payload.split.shares or []
        ]
    try:
        expense, replayed = await service.create_fast_split(
            group_id=group_id,
            actor_user_id=actor_user_id,
            payer_user_id=payload.payer_user_id,
            receipt_id=payload.receipt_id,
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
        public_code = {
            "percentage_total_must_be_100": "invalid_percentage_total",
            "exact_total_must_match_expense": "invalid_split_total",
            "idempotency_key_reused": "idempotency_conflict",
        }.get(error.code, error.code)
        raise HTTPException(
            code, detail={"code": public_code, "message": message}
        ) from None
    except IntegrityError as error:
        await db.rollback()
        if not _is_idempotency_collision(error):
            raise
        expense = await service.repository.get_by_idempotency_key(
            group_id=group_id,
            created_by_id=actor_user_id,
            key=idempotency_key,
        )
        if expense is None or expense.idempotency_request_hash != request_hash:
            message = _EXPENSE_ERRORS["idempotency_key_reused"][1]
            raise HTTPException(
                409, detail={"code": "idempotency_conflict", "message": message}
            ) from None
        replayed = True
    if replayed:
        response.status_code = status.HTTP_200_OK
        response.headers["Idempotency-Replayed"] = "true"
    return await _expense_response(expense, db)


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
