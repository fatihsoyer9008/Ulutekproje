import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    require_group_admin,
    require_group_member,
    require_group_owner,
)
from app.core.database import get_db_session
from app.group_schemas import (
    GroupCreateRequest,
    GroupMemberCreateRequest,
    GroupMemberEnvelope,
    GroupMemberRoleUpdateRequest,
    GroupResponse,
    GroupsResponse,
    GroupUpdateRequest,
)
from app.models.group import GroupMember
from app.models.user import User
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


def _raise_group_error(error: GroupServiceError) -> None:
    status_code, message = _ERRORS[error.code]
    raise HTTPException(
        status_code=status_code,
        detail={"code": error.code, "message": message},
    ) from None


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
