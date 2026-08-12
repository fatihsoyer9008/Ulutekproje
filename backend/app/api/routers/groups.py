import hashlib
import json
import uuid
from typing import Annotated, NoReturn

from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Query,
    Response,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    require_group_admin,
    require_group_member,
    require_group_owner,
)
from app.core.config import settings
from app.core.database import get_db_session
from app.core.security import privacy_hash
from app.group_schemas import (
    GroupCreateRequest,
    GroupExpenseDataResponse,
    GroupExpenseEnvelope,
    GroupMemberCreateRequest,
    GroupMemberEnvelope,
    GroupMemberRoleUpdateRequest,
    GroupResponse,
    GroupsResponse,
    GroupUpdateRequest,
    ItemizedExpenseCreateRequest,
)
from app.models.group import GroupMember
from app.models.user import User
from app.repositories.group_expense_idempotency import (
    GroupExpenseIdempotencyRepository,
)
from app.repositories.group_expenses import GroupExpenseRepository
from app.services.group_expense_service import (
    ExtraAmountInput,
    ExtraAmountShareInput,
    GroupExpenseService,
    ItemizedExpenseValidationError,
    LineItemAssignmentInput,
)
from app.services.group_service import GroupService, GroupServiceError

router = APIRouter(prefix="/api/v1/groups", tags=["groups"])

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
_ITEMIZED_EXPENSE_ERRORS = {
    "group_not_found": (
        status.HTTP_404_NOT_FOUND,
        "Grup bulunamadı.",
    ),
    "group_forbidden": (
        status.HTTP_403_FORBIDDEN,
        "Bu grup için yetkiniz yok.",
    ),
    "member_not_found": (
        status.HTTP_404_NOT_FOUND,
        "Grup üyesi bulunamadı.",
    ),
    "receipt_not_synced": (
        status.HTTP_409_CONFLICT,
        "Fiş veya ürünler henüz bulut kaydına aktarılmamış.",
    ),
    "invalid_request": (
        status.HTTP_400_BAD_REQUEST,
        "Masraf isteği geçersiz.",
    ),
    "invalid_split_total": (
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        "Payların toplamı masraf toplamına eşit olmalıdır.",
    ),
    "unassigned_line_items": (
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        "Atanmayan fiş ürünleri bulunuyor.",
    ),
    "currency_mismatch": (
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        "Masraf para birimi grup para birimiyle aynı olmalıdır.",
    ),
}


def _raise_itemized_expense_error(
    error: ItemizedExpenseValidationError,
) -> NoReturn:
    status_code, message = _ITEMIZED_EXPENSE_ERRORS[error.code]
    detail: dict[str, object] = {
        "code": error.code,
        "message": message,
    }

    if error.unassigned_receipt_line_item_ids:
        detail["unassigned_receipt_line_item_ids"] = [
            str(line_item_id) for line_item_id in error.unassigned_receipt_line_item_ids
        ]

    raise HTTPException(
        status_code=status_code,
        detail=detail,
    ) from None


def _itemized_expense_request_hash(
    payload: ItemizedExpenseCreateRequest,
) -> str:
    canonical = json.dumps(
        payload.model_dump(mode="json"),
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def _raise_expense_idempotency_conflict() -> NoReturn:
    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={
            "code": "idempotency_conflict",
            "message": (
                "Idempotency-Key daha önce farklı bir masraf isteği için " "kullanıldı."
            ),
        },
    ) from None


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


@router.post(
    "/{group_id}/expenses",
    response_model=GroupExpenseEnvelope,
    status_code=status.HTTP_201_CREATED,
)
async def create_itemized_expense(
    group_id: uuid.UUID,
    payload: ItemizedExpenseCreateRequest,
    idempotency_key: Annotated[
        str,
        Header(
            alias="Idempotency-Key",
            min_length=8,
            max_length=128,
        ),
    ],
    actor_membership: GroupMember = Depends(require_group_member),
    db: AsyncSession = Depends(get_db_session),
) -> GroupExpenseEnvelope:
    actor_user_id = actor_membership.user_id
    key_hash = privacy_hash(
        "group-expense-create:" f"{group_id}:{actor_user_id}:{idempotency_key}"
    )
    request_hash = _itemized_expense_request_hash(payload)

    idempotency_repository = GroupExpenseIdempotencyRepository(db)
    idempotency_record = await idempotency_repository.try_create(
        group_id=group_id,
        actor_user_id=actor_user_id,
        idempotency_key_hash=key_hash,
        request_hash=request_hash,
    )

    if idempotency_record is None:
        previous = await idempotency_repository.get(
            group_id=group_id,
            actor_user_id=actor_user_id,
            idempotency_key_hash=key_hash,
        )
        if previous is None:
            raise RuntimeError("Group expense idempotency record disappeared")
        if previous.request_hash != request_hash:
            _raise_expense_idempotency_conflict()
        if previous.expense_id is None:
            raise RuntimeError("Group expense idempotency result is unavailable")

        replayed_expense = await GroupExpenseRepository(db).get_by_id(
            previous.expense_id
        )
        if replayed_expense is None or replayed_expense.group_id != group_id:
            raise RuntimeError("Group expense idempotency expense is unavailable")

        replay_service = GroupExpenseService(db)
        replay_display_names = await replay_service.get_expense_share_display_names(
            replayed_expense
        )
        return GroupExpenseEnvelope(
            expense=GroupExpenseDataResponse.from_model(
                replayed_expense,
                display_names=replay_display_names,
            )
        )

    assignments = [
        LineItemAssignmentInput(
            receipt_line_item_id=line_item.receipt_line_item_id,
            user_id=share.user_id,
            amount_in_minor=share.amount_in_minor,
            quantity_share_milli=share.quantity_share_milli,
        )
        for line_item in payload.split.line_items
        for share in line_item.shares
    ]
    extra_amounts = [
        ExtraAmountInput(
            type=extra_amount.type,
            label=extra_amount.label,
            amount_in_minor=extra_amount.amount_in_minor,
            shares=tuple(
                ExtraAmountShareInput(
                    user_id=share.user_id,
                    amount_in_minor=share.amount_in_minor,
                )
                for share in extra_amount.shares
            ),
        )
        for extra_amount in payload.split.extra_amounts
    ]

    service = GroupExpenseService(db)
    try:
        expense = await service.create_itemized(
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
            extra_amounts=extra_amounts,
        )
    except ItemizedExpenseValidationError as error:
        _raise_itemized_expense_error(error)

    display_names = await service.get_expense_share_display_names(expense)
    response = GroupExpenseEnvelope(
        expense=GroupExpenseDataResponse.from_model(
            expense,
            display_names=display_names,
        )
    )

    idempotency_record.expense_id = expense.id
    await db.commit()
    return response


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
