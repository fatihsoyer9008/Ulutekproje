import uuid

import pytest

from app.core.config import settings
from app.models import GroupMember, GroupRole
from app.repositories.groups import GroupRepository


async def _group_with_roles(session_factory, owner, admin, member):
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="RBAC Grubu", created_by=owner.id)
        await repository.add_member(
            group_id=group.id, user_id=admin.id, role=GroupRole.admin
        )
        await repository.add_member(group_id=group.id, user_id=member.id)
        await session.commit()
        return group.id


def _assert_error(response, status_code: int, code: str) -> None:
    assert response.status_code == status_code
    detail = response.json()["detail"]
    assert detail["code"] == code
    assert detail["message"]


@pytest.mark.asyncio
async def test_only_admin_or_owner_can_add_members(group_api_context) -> None:
    client, factory, current, owner, member, admin, outsider = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)

    current["value"] = member
    denied_member = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(outsider.id), "role": "member"},
    )
    _assert_error(denied_member, 403, "group_forbidden")

    current["value"] = outsider
    denied_outsider = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(outsider.id), "role": "member"},
    )
    _assert_error(denied_outsider, 403, "group_forbidden")

    current["value"] = admin
    added = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(outsider.id), "role": "member"},
    )
    assert added.status_code == 201
    assert added.json()["member"]["role"] == "member"
    assert current["debt_cache"].invalidated_group_ids == [group_id]

    duplicate = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(outsider.id), "role": "member"},
    )
    _assert_error(duplicate, 409, "member_already_exists")


@pytest.mark.asyncio
async def test_admin_cannot_assign_admin_but_owner_can(group_api_context) -> None:
    client, factory, current, owner, member, admin, outsider = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)

    current["value"] = admin
    denied = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(outsider.id), "role": "admin"},
    )
    _assert_error(denied, 403, "group_forbidden")

    current["value"] = owner
    added = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(outsider.id), "role": "admin"},
    )
    assert added.status_code == 201
    assert added.json()["member"]["role"] == "admin"


@pytest.mark.asyncio
async def test_self_leave_is_allowed_for_admin_and_member(group_api_context) -> None:
    client, factory, current, owner, member, admin, _ = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)

    for departing in (member, admin):
        current["value"] = departing
        response = await client.delete(
            f"/api/v1/groups/{group_id}/members/{departing.id}"
        )
        assert response.status_code == 204

    async with factory() as session:
        for departed in (member, admin):
            membership = await session.get(GroupMember, (group_id, departed.id))
            assert membership is not None and membership.left_at is not None


@pytest.mark.asyncio
async def test_self_leave_rejects_unsettled_member(group_api_context) -> None:
    client, factory, current, owner, member, admin, _ = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)

    current["value"] = owner
    expense = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers={"Idempotency-Key": "leave-unsettled-0001"},
        json={
            "receipt_id": None,
            "payer_user_id": str(owner.id),
            "title": "Ortak market",
            "note": None,
            "expense_date": "2026-08-21T10:00:00Z",
            "total_amount_in_minor": 10_000,
            "currency": "TRY",
            "split": {
                "type": "equal",
                "member_ids": [str(owner.id), str(member.id)],
            },
        },
    )
    assert expense.status_code == 201

    current["value"] = member
    response = await client.delete(f"/api/v1/groups/{group_id}/members/me")

    _assert_error(response, 409, "member_has_unsettled_balance")


@pytest.mark.asyncio
async def test_admin_removing_unsettled_member_is_rejected(
    group_api_context,
) -> None:
    client, factory, current, owner, member, admin, _ = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)

    current["value"] = owner
    expense = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        headers={"Idempotency-Key": "remove-unsettled-0001"},
        json={
            "receipt_id": None,
            "payer_user_id": str(owner.id),
            "title": "Ortak market",
            "note": None,
            "expense_date": "2026-08-21T10:00:00Z",
            "total_amount_in_minor": 10_000,
            "currency": "TRY",
            "split": {
                "type": "equal",
                "member_ids": [str(owner.id), str(member.id)],
            },
        },
    )
    assert expense.status_code == 201

    current["value"] = admin
    response = await client.delete(
        f"/api/v1/groups/{group_id}/members/{member.id}"
    )

    _assert_error(response, 409, "member_has_unsettled_balance")


@pytest.mark.asyncio
async def test_last_owner_cannot_leave(group_api_context) -> None:
    client, factory, current, owner, member, admin, _ = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)
    current["value"] = owner

    response = await client.delete(f"/api/v1/groups/{group_id}/members/{owner.id}")

    _assert_error(response, 409, "last_owner_required")
    assert "Son owner gruptan ayrılamaz" in response.json()["detail"]["message"]


@pytest.mark.asyncio
async def test_kick_requires_strictly_higher_role(group_api_context) -> None:
    client, factory, current, owner, member, admin, outsider = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)

    cases = [
        (member, admin, 403),
        (member, owner, 403),
        (admin, owner, 403),
        (admin, member, 204),
    ]
    for actor, target, expected in cases:
        current["value"] = actor
        response = await client.delete(f"/api/v1/groups/{group_id}/members/{target.id}")
        assert response.status_code == expected
        if expected == 403:
            assert response.json()["detail"]["code"] == "group_forbidden"

    current["value"] = outsider
    denied = await client.delete(f"/api/v1/groups/{group_id}/members/{uuid.uuid4()}")
    _assert_error(denied, 403, "group_forbidden")


@pytest.mark.asyncio
async def test_single_owner_can_transfer_ownership_atomically(
    group_api_context,
) -> None:
    client, factory, current, owner, member, admin, _ = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)
    current["value"] = owner

    transferred = await client.patch(
        f"/api/v1/groups/{group_id}/members/{member.id}",
        json={"role": "owner"},
    )

    assert transferred.status_code == 200
    assert transferred.json()["member"]["role"] == "owner"
    async with factory() as session:
        old_owner = await session.get(GroupMember, (group_id, owner.id))
        new_owner = await session.get(GroupMember, (group_id, member.id))
        assert old_owner is not None and old_owner.role is GroupRole.admin
        assert new_owner is not None and new_owner.role is GroupRole.owner

    leaving = await client.delete(f"/api/v1/groups/{group_id}/members/{owner.id}")
    assert leaving.status_code == 204


@pytest.mark.asyncio
async def test_only_owner_can_change_roles(group_api_context) -> None:
    client, factory, current, owner, member, admin, outsider = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)

    for unauthorized in (admin, member, outsider):
        current["value"] = unauthorized
        response = await client.patch(
            f"/api/v1/groups/{group_id}/members/{member.id}",
            json={"role": "admin"},
        )
        _assert_error(response, 403, "group_forbidden")


@pytest.mark.asyncio
async def test_last_owner_cannot_be_demoted_without_transfer(
    group_api_context,
) -> None:
    client, factory, current, owner, member, admin, _ = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)
    current["value"] = owner

    response = await client.patch(
        f"/api/v1/groups/{group_id}/members/{owner.id}",
        json={"role": "admin"},
    )

    _assert_error(response, 409, "last_owner_required")


@pytest.mark.asyncio
async def test_owner_can_promote_and_demote_when_an_owner_remains(
    group_api_context,
) -> None:
    client, factory, current, owner, member, admin, _ = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)
    async with factory() as session:
        second_owner = await session.get(GroupMember, (group_id, admin.id))
        assert second_owner is not None
        second_owner.role = GroupRole.owner
        await session.commit()
    current["value"] = owner

    promoted = await client.patch(
        f"/api/v1/groups/{group_id}/members/{member.id}",
        json={"role": "admin"},
    )
    demoted = await client.patch(
        f"/api/v1/groups/{group_id}/members/{admin.id}",
        json={"role": "member"},
    )

    assert promoted.status_code == 200
    assert promoted.json()["member"]["role"] == "admin"
    assert demoted.status_code == 200
    assert demoted.json()["member"]["role"] == "member"


@pytest.mark.asyncio
async def test_direct_member_add_is_hidden_in_production(
    group_api_context,
    monkeypatch,
) -> None:
    client, factory, _, owner, member, _, _ = group_api_context
    group_id = await _create_owner_only_group(factory, owner)
    monkeypatch.setattr(settings, "app_env", "production")

    response = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(member.id), "role": "member"},
    )

    _assert_error(response, 404, "group_not_found")


@pytest.mark.asyncio
async def test_direct_member_add_is_available_in_development(
    group_api_context,
    monkeypatch,
) -> None:
    client, factory, _, owner, member, _, _ = group_api_context
    group_id = await _create_owner_only_group(factory, owner)
    monkeypatch.setattr(settings, "app_env", "development")

    response = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(member.id), "role": "member"},
    )

    assert response.status_code == 201


@pytest.mark.asyncio
@pytest.mark.parametrize("departing_role", [GroupRole.member, GroupRole.admin])
async def test_member_and_admin_can_leave_through_me_route(
    group_api_context,
    departing_role,
) -> None:
    client, factory, current, owner, member, _, _ = group_api_context
    async with factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Self Leave", created_by=owner.id)
        await repository.add_member(
            group_id=group.id,
            user_id=member.id,
            role=departing_role,
        )
        await session.commit()
        group_id = group.id
    current["value"] = member

    response = await client.delete(f"/api/v1/groups/{group_id}/members/me")

    assert response.status_code == 204
    async with factory() as session:
        membership = await session.get(GroupMember, (group_id, member.id))
        assert membership is not None and membership.left_at is not None


@pytest.mark.asyncio
async def test_last_owner_cannot_leave_through_me_route(group_api_context) -> None:
    client, factory, current, owner, _, _, _ = group_api_context
    group_id = await _create_owner_only_group(factory, owner)
    current["value"] = owner

    response = await client.delete(f"/api/v1/groups/{group_id}/members/me")

    _assert_error(response, 409, "last_owner_required")


@pytest.mark.asyncio
async def test_me_route_ignores_other_user_id_and_leaves_authenticated_user(
    group_api_context,
) -> None:
    client, factory, current, owner, member, admin, _ = group_api_context
    group_id = await _group_with_roles(factory, owner, admin, member)
    current["value"] = admin

    response = await client.delete(
        f"/api/v1/groups/{group_id}/members/me",
        params={"user_id": str(member.id)},
    )

    assert response.status_code == 204
    async with factory() as session:
        admin_membership = await session.get(GroupMember, (group_id, admin.id))
        member_membership = await session.get(GroupMember, (group_id, member.id))
        assert admin_membership is not None and admin_membership.left_at is not None
        assert member_membership is not None and member_membership.left_at is None


async def _create_owner_only_group(session_factory, owner):
    async with session_factory() as session:
        group = await GroupRepository(session).create(
            name="Owner Only",
            created_by=owner.id,
        )
        await session.commit()
        return group.id
