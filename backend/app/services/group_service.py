import uuid
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.group_schemas import (
    GroupDetailResponse,
    GroupMemberListItemResponse,
    GroupMemberResponse,
    GroupSummaryResponse,
)
from app.models.group import Group, GroupMember, GroupRole
from app.repositories.groups import GroupMemberAlreadyExists, GroupRepository
from app.repositories.users import UserRepository
from app.services.debt_summary_service import DebtSummaryService


class GroupServiceError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class GroupService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = GroupRepository(session)

    async def create(
        self,
        *,
        actor_user_id: uuid.UUID,
        name: str,
        description: str | None,
        currency: str,
    ) -> GroupDetailResponse:
        group = await self.repository.create(
            name=name,
            description=description,
            currency=currency,
            created_by=actor_user_id,
        )
        stored = await self.repository.get_by_id(group.id, include_members=True)
        if stored is None:  # pragma: no cover - database invariant guard
            raise RuntimeError("created group could not be reloaded")
        # A brand-new group cannot have any expenses yet.
        response = _group_detail(
            stored,
            actor_user_id,
            net_amount_in_minor=0,
            has_activity=False,
        )
        await self.session.commit()
        return response

    async def list_for_user(
        self,
        *,
        actor_user_id: uuid.UUID,
        include_archived: bool,
    ) -> list[GroupSummaryResponse]:
        groups = await self.repository.list_for_user(
            actor_user_id,
            include_archived=include_archived,
        )
        group_ids = [group.id for group in groups]
        debt_service = DebtSummaryService(self.session)
        balances = await debt_service.get_group_net_balances(
            user_id=actor_user_id,
            group_ids=group_ids,
        )
        active_group_ids = await debt_service.get_groups_with_activity(group_ids)
        return [
            _group_summary(
                group,
                actor_user_id,
                net_amount_in_minor=balances.get(group.id, 0),
                has_activity=group.id in active_group_ids,
            )
            for group in groups
        ]

    async def get_detail(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
    ) -> GroupDetailResponse:
        group = await self._get_authorized_group(
            group_id=group_id,
            actor_user_id=actor_user_id,
        )
        debt_service = DebtSummaryService(self.session)
        balances = await debt_service.get_group_net_balances(
            user_id=actor_user_id,
            group_ids=[group.id],
        )
        active_group_ids = await debt_service.get_groups_with_activity([group.id])
        return _group_detail(
            group,
            actor_user_id,
            net_amount_in_minor=balances.get(group.id, 0),
            has_activity=group.id in active_group_ids,
        )

    async def list_members(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
    ) -> list[GroupMemberListItemResponse]:
        group = await self._get_authorized_group(
            group_id=group_id,
            actor_user_id=actor_user_id,
        )
        return [
            GroupMemberListItemResponse(
                group_id=member.group_id,
                user_id=member.user_id,
                name=_display_name(member),
                email=member.user.email if member.user is not None else None,
                role=member.role,
                joined_at=_as_utc(member.joined_at),
                left_at=_as_utc(member.left_at),
            )
            for member in sorted(
                group.members,
                key=lambda item: (_as_utc(item.joined_at), str(item.user_id)),
            )
        ]

    async def update(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        changes: dict[str, object],
    ) -> GroupDetailResponse:
        group = await self._get_authorized_group(
            group_id=group_id,
            actor_user_id=actor_user_id,
            require_owner=True,
            for_update=True,
        )
        if "name" in changes:
            group.name = str(changes["name"])
        if "description" in changes:
            description = changes["description"]
            group.description = str(description) if description is not None else None
        group.updated_at = datetime.now(UTC)
        await self.session.flush()

        stored = await self.repository.get_by_id(group.id, include_members=True)
        if stored is None:  # pragma: no cover - database invariant guard
            raise RuntimeError("updated group could not be reloaded")
        debt_service = DebtSummaryService(self.session)
        balances = await debt_service.get_group_net_balances(
            user_id=actor_user_id,
            group_ids=[stored.id],
        )
        active_group_ids = await debt_service.get_groups_with_activity([stored.id])
        response = _group_detail(
            stored,
            actor_user_id,
            net_amount_in_minor=balances.get(stored.id, 0),
            has_activity=stored.id in active_group_ids,
        )
        await self.session.commit()
        return response

    async def archive(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
    ) -> None:
        group = await self._get_authorized_group(
            group_id=group_id,
            actor_user_id=actor_user_id,
            require_owner=True,
            for_update=True,
        )
        if group.archived_at is None:
            archived_at = datetime.now(UTC)
            group.archived_at = archived_at
            group.updated_at = archived_at
            await self.session.commit()

    async def add_member(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        user_id: uuid.UUID,
        role: GroupRole,
    ) -> GroupMemberResponse:
        group = await self._get_authorized_group(
            group_id=group_id, actor_user_id=actor_user_id, for_update=True
        )
        actor = _active_membership(group, actor_user_id)
        if actor is None or actor.role not in {GroupRole.admin, GroupRole.owner}:
            raise GroupServiceError("group_forbidden")
        if role is GroupRole.owner or (
            role is GroupRole.admin and actor.role is not GroupRole.owner
        ):
            raise GroupServiceError("group_forbidden")
        if await UserRepository(self.session).get_by_id(user_id) is None:
            raise GroupServiceError("user_not_found")
        try:
            member = await self.repository.add_member(
                group_id=group_id, user_id=user_id, role=role
            )
        except GroupMemberAlreadyExists:
            raise GroupServiceError("member_already_exists") from None
        await self.session.refresh(member, attribute_names=["user"])
        response = _member_response(member)
        await self.session.commit()
        return response

    async def remove_member(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> None:
        group = await self._get_authorized_group(
            group_id=group_id, actor_user_id=actor_user_id, for_update=True
        )
        actor = _active_membership(group, actor_user_id)
        target = _active_membership(group, user_id)
        if target is None:
            raise GroupServiceError("member_not_found")
        if actor_user_id != user_id:
            role_rank = {GroupRole.member: 1, GroupRole.admin: 2, GroupRole.owner: 3}
            if actor is None or role_rank[actor.role] <= role_rank[target.role]:
                raise GroupServiceError("group_forbidden")
        if (
            target.role is GroupRole.owner
            and sum(
                member.role is GroupRole.owner
                for member in group.members
                if member.left_at is None
            )
            == 1
        ):
            raise GroupServiceError("last_owner_required")
        target.left_at = datetime.now(UTC)
        await self.session.commit()

    async def update_member_role(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        user_id: uuid.UUID,
        role: GroupRole,
    ) -> GroupMemberResponse:
        group = await self._get_authorized_group(
            group_id=group_id,
            actor_user_id=actor_user_id,
            require_owner=True,
            for_update=True,
        )
        actor = _active_membership(group, actor_user_id)
        target = _active_membership(group, user_id)
        if target is None:
            raise GroupServiceError("member_not_found")
        if target.role is role:
            return _member_response(target)

        active_owners = [
            member
            for member in group.members
            if member.left_at is None and member.role is GroupRole.owner
        ]
        if target.role is GroupRole.owner and len(active_owners) == 1:
            raise GroupServiceError("last_owner_required")

        target.role = role
        # A single owner's promotion of another member is an atomic transfer,
        # rather than temporarily leaving two owners behind.
        if (
            role is GroupRole.owner
            and actor is not None
            and actor.user_id != target.user_id
            and len(active_owners) == 1
        ):
            actor.role = GroupRole.admin

        await self.session.flush()
        response = _member_response(target)
        await self.session.commit()
        return response

    async def _get_authorized_group(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        require_owner: bool = False,
        for_update: bool = False,
    ) -> Group:
        group = await self.repository.get_by_id(
            group_id,
            include_members=True,
            for_update=for_update,
        )
        if group is None:
            raise GroupServiceError("group_not_found")

        membership = _active_membership(group, actor_user_id)
        if membership is None or (
            require_owner and membership.role is not GroupRole.owner
        ):
            raise GroupServiceError("group_forbidden")
        return group


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _active_members(group: Group) -> list[GroupMember]:
    return sorted(
        (member for member in group.members if member.left_at is None),
        key=lambda member: (_as_utc(member.joined_at), str(member.user_id)),
    )


def _active_membership(
    group: Group,
    user_id: uuid.UUID,
) -> GroupMember | None:
    return next(
        (
            member
            for member in group.members
            if member.user_id == user_id and member.left_at is None
        ),
        None,
    )


def _display_name(member: GroupMember) -> str:
    if member.user is None:
        return "Silinmiş kullanıcı"
    return member.user.display_name or "Kullanıcı"


def _member_response(member: GroupMember) -> GroupMemberResponse:
    return GroupMemberResponse(
        group_id=member.group_id,
        user_id=member.user_id,
        display_name=_display_name(member),
        role=member.role,
        joined_at=_as_utc(member.joined_at),
        left_at=_as_utc(member.left_at),
    )


def _group_status(*, net_amount_in_minor: int, has_activity: bool) -> str:
    if not has_activity:
        return "no_expenses"
    if net_amount_in_minor > 0:
        return "you_are_owed"
    if net_amount_in_minor < 0:
        return "you_owe"
    return "settled_up"


def _group_summary(
    group: Group,
    current_user_id: uuid.UUID,
    *,
    net_amount_in_minor: int,
    has_activity: bool,
) -> GroupSummaryResponse:
    members = _active_members(group)
    current_membership = next(
        (member for member in members if member.user_id == current_user_id),
        None,
    )
    if current_membership is None:  # pragma: no cover - repository invariant guard
        raise GroupServiceError("group_forbidden")
    return GroupSummaryResponse(
        id=group.id,
        name=group.name,
        description=group.description,
        currency=group.currency,
        member_count=len(members),
        current_user_role=current_membership.role,
        current_user_net_amount_in_minor=net_amount_in_minor,
        status=_group_status(
            net_amount_in_minor=net_amount_in_minor,
            has_activity=has_activity,
        ),
        created_by=group.created_by,
        created_at=_as_utc(group.created_at),
        updated_at=_as_utc(group.updated_at),
        archived_at=_as_utc(group.archived_at),
    )


def _group_detail(
    group: Group,
    current_user_id: uuid.UUID,
    *,
    net_amount_in_minor: int,
    has_activity: bool,
) -> GroupDetailResponse:
    summary = _group_summary(
        group,
        current_user_id,
        net_amount_in_minor=net_amount_in_minor,
        has_activity=has_activity,
    )
    members = [
        GroupMemberResponse(
            group_id=member.group_id,
            user_id=member.user_id,
            display_name=_display_name(member),
            role=member.role,
            joined_at=_as_utc(member.joined_at),
            left_at=None,
        )
        for member in _active_members(group)
    ]
    return GroupDetailResponse(**summary.model_dump(), members=members)
