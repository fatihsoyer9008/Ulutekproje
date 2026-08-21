import logging
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from fastapi import HTTPException, status
from sqlalchemy import func, select

from app.api.dependencies import get_current_user, get_email_sender, get_rate_limiter
from app.core.rate_limit import RateLimitRule
from app.core.security import hash_token
from app.main import app
from app.models import GroupInvitation, GroupMember, GroupRole, User
from app.repositories.groups import GroupRepository
from tests.test_group_api import group_api_context

__all__ = ("group_api_context",)


@dataclass
class CapturingInvitationEmailSender:
    invitations: list[dict[str, str]] = field(default_factory=list)

    async def send_group_invitation(
        self,
        *,
        email: str,
        token: str,
        group_name: str,
    ) -> None:
        self.invitations.append(
            {
                "email": email,
                "token": token,
                "group_name": group_name,
            }
        )


class FailingInvitationEmailSender(CapturingInvitationEmailSender):
    async def send_group_invitation(
        self,
        *,
        email: str,
        token: str,
        group_name: str,
    ) -> None:
        del email, token, group_name
        raise RuntimeError("simulated delivery failure")


@dataclass
class RecordingRateLimiter:
    calls: list[tuple[RateLimitRule, str]] = field(default_factory=list)
    reject: bool = False

    async def enforce(
        self,
        rule: RateLimitRule,
        *,
        identifier: str,
    ) -> None:
        self.calls.append((rule, identifier))
        if self.reject:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests.",
                headers={"Retry-After": "60"},
            )


@pytest_asyncio.fixture
async def invitation_api_context(group_api_context):
    sender = CapturingInvitationEmailSender()
    limiter = RecordingRateLimiter()
    app.dependency_overrides[get_email_sender] = lambda: sender
    app.dependency_overrides[get_rate_limiter] = lambda: limiter
    yield (*group_api_context, sender, limiter)


async def _create_group(session_factory, owner_id: uuid.UUID) -> uuid.UUID:
    async with session_factory() as session:
        group = await GroupRepository(session).create(
            name="Davet Test Grubu",
            created_by=owner_id,
        )
        await session.commit()
        return group.id


async def _verify_user(session_factory, user: User) -> None:
    async with session_factory() as session:
        stored_user = await session.get(User, user.id)
        assert stored_user is not None
        stored_user.is_email_verified = True
        await session.commit()
    user.is_email_verified = True


@pytest.mark.asyncio
async def test_create_invitation_stores_only_hash_with_24_hour_expiry_and_limits(
    invitation_api_context,
) -> None:
    client, session_factory, _, owner, _, _, _, sender, limiter = (
        invitation_api_context
    )
    group_id = await _create_group(session_factory, owner.id)

    response = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": "  NEW.USER@Example.COM ", "role": "admin"},
    )

    assert response.status_code == 202
    assert response.json() == {"status": "request_received"}
    assert len(sender.invitations) == 1
    delivered = sender.invitations[0]
    assert delivered["email"] == "new.user@example.com"
    assert delivered["group_name"] == "Davet Test Grubu"

    async with session_factory() as session:
        invitation = (await session.scalars(select(GroupInvitation))).one()
        assert invitation.group_id == group_id
        assert invitation.invited_email == "new.user@example.com"
        assert invitation.role is GroupRole.admin
        assert invitation.invited_by_user_id == owner.id
        assert invitation.accepted_at is None
        assert invitation.accepted_by_user_id is None
        assert invitation.token_hash == hash_token(delivered["token"])
        assert delivered["token"] not in invitation.token_hash
        expires_at = invitation.expires_at
        created_at = invitation.created_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=UTC)
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=UTC)
        assert abs((expires_at - created_at) - timedelta(hours=24)) < timedelta(
            seconds=1
        )

    assert [rule.name for rule, _ in limiter.calls] == [
        "group-invitation-user-hourly",
        "group-invitation-group-hourly",
        "group-invitation-email-daily",
    ]
    assert [identifier for _, identifier in limiter.calls] == [
        f"user:{owner.id}",
        f"group:{group_id}",
        "email:new.user@example.com",
    ]


@pytest.mark.asyncio
async def test_creation_response_does_not_enumerate_account_state(
    invitation_api_context,
) -> None:
    client, session_factory, _, owner, member, _, _, sender, _ = (
        invitation_api_context
    )
    group_id = await _create_group(session_factory, owner.id)

    responses = [
        await client.post(
            f"/api/v1/groups/{group_id}/invitations",
            json={"email": email, "role": "member"},
        )
        for email in (
            owner.email,
            member.email,
            "not-registered@example.com",
        )
    ]

    assert [response.status_code for response in responses] == [202, 202, 202]
    assert [response.json() for response in responses] == [
        {"status": "request_received"},
        {"status": "request_received"},
        {"status": "request_received"},
    ]
    assert len(sender.invitations) == 3


@pytest.mark.asyncio
async def test_invitation_creation_enforces_rbac_and_admin_member_only_rule(
    invitation_api_context,
) -> None:
    client, session_factory, current, owner, member, outsider, former, sender, _ = (
        invitation_api_context
    )
    group_id = await _create_group(session_factory, owner.id)
    async with session_factory() as session:
        repository = GroupRepository(session)
        await repository.add_member(
            group_id=group_id,
            user_id=member.id,
            role=GroupRole.admin,
        )
        await repository.add_member(
            group_id=group_id,
            user_id=former.id,
            role=GroupRole.member,
        )
        await session.commit()

    current["value"] = outsider
    outsider_response = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": "invitee@example.com", "role": "member"},
    )
    assert outsider_response.status_code == 403

    current["value"] = former
    member_response = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": "invitee@example.com", "role": "member"},
    )
    assert member_response.status_code == 403

    current["value"] = member
    admin_forbidden = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": "invitee@example.com", "role": "admin"},
    )
    assert admin_forbidden.status_code == 403
    assert admin_forbidden.json()["detail"]["code"] == "group_forbidden"

    admin_allowed = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": "invitee@example.com", "role": "member"},
    )
    assert admin_allowed.status_code == 202

    current["value"] = owner
    owner_role_forbidden = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": "invitee@example.com", "role": "owner"},
    )
    assert owner_role_forbidden.status_code == 403
    assert len(sender.invitations) == 1


@pytest.mark.asyncio
async def test_invitation_rate_limit_uses_public_error_contract(
    invitation_api_context,
) -> None:
    client, session_factory, _, owner, _, _, _, sender, limiter = (
        invitation_api_context
    )
    group_id = await _create_group(session_factory, owner.id)
    limiter.reject = True

    response = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": "limited@example.com", "role": "member"},
    )

    assert response.status_code == 429
    assert response.json()["detail"]["code"] == "invitation_rate_limited"
    assert response.headers["retry-after"] == "60"
    assert sender.invitations == []
    async with session_factory() as session:
        assert await session.scalar(select(func.count(GroupInvitation.id))) == 0


@pytest.mark.asyncio
async def test_delivery_failure_keeps_general_response_without_logging_email(
    invitation_api_context,
    caplog,
) -> None:
    client, session_factory, _, owner, _, _, _, _, _ = invitation_api_context
    group_id = await _create_group(session_factory, owner.id)
    sender = FailingInvitationEmailSender()
    app.dependency_overrides[get_email_sender] = lambda: sender
    raw_email = "private.invitee@example.com"
    caplog.set_level(logging.ERROR, logger="app.api.routers.group_invitations")

    response = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": raw_email, "role": "member"},
    )

    assert response.status_code == 202
    assert response.json() == {"status": "request_received"}
    assert raw_email not in caplog.text
    assert "email_hash=" in caplog.text
    async with session_factory() as session:
        assert await session.scalar(select(func.count(GroupInvitation.id))) == 1


@pytest.mark.asyncio
async def test_invitation_landing_page_links_to_app_deep_link(
    invitation_api_context,
) -> None:
    client, *_ = invitation_api_context

    response = await client.get(
        "/api/v1/group-invitation", params={"token": "some-token"}
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert "fiskon://auth/group-invitation?token=some-token" in response.text


@pytest.mark.asyncio
async def test_accept_requires_auth_and_unknown_token_returns_gone(
    invitation_api_context,
) -> None:
    client, _, _, _, _, _, _, _, _ = invitation_api_context
    override = app.dependency_overrides.pop(get_current_user)
    try:
        unauthorized = await client.post(
            "/api/v1/group-invitations/unknown-token/accept"
        )
    finally:
        app.dependency_overrides[get_current_user] = override

    assert unauthorized.status_code == 401
    assert unauthorized.json()["detail"]["code"] == "unauthorized"
    assert unauthorized.headers["cache-control"] == "no-store"

    gone = await client.post("/api/v1/group-invitations/unknown-token/accept")
    assert gone.status_code == 410
    assert gone.json()["detail"]["code"] == "invitation_expired_or_used"
    assert gone.headers["cache-control"] == "no-store"


@pytest.mark.asyncio
async def test_accept_invitation_creates_membership_invalidates_cache_and_is_one_time(
    invitation_api_context,
) -> None:
    client, session_factory, current, owner, member, _, _, sender, _ = (
        invitation_api_context
    )
    group_id = await _create_group(session_factory, owner.id)
    await _verify_user(session_factory, member)
    created = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": member.email, "role": "member"},
    )
    assert created.status_code == 202
    token = sender.invitations[-1]["token"]
    current["value"] = member

    accepted = await client.post(
        f"/api/v1/group-invitations/{token}/accept"
    )

    assert accepted.status_code == 201
    assert accepted.json()["member"]["user_id"] == str(member.id)
    assert accepted.json()["member"]["role"] == "member"
    assert current["debt_cache"].invalidated_group_ids == [group_id]

    replay = await client.post(f"/api/v1/group-invitations/{token}/accept")
    assert replay.status_code == 410
    assert replay.json()["detail"]["code"] == "invitation_expired_or_used"

    async with session_factory() as session:
        invitation = (
            await session.scalars(
                select(GroupInvitation).where(
                    GroupInvitation.token_hash == hash_token(token)
                )
            )
        ).one()
        membership = await session.get(GroupMember, (group_id, member.id))
        assert invitation.accepted_at is not None
        assert invitation.accepted_by_user_id == member.id
        assert membership is not None
        assert membership.left_at is None
        invitation_id = invitation.id

        stored_user = await session.get(User, member.id)
        assert stored_user is not None
        await session.delete(stored_user)
        await session.commit()
        session.expire_all()
        stored_invitation = await session.get(GroupInvitation, invitation_id)
        assert stored_invitation is not None
        assert stored_invitation.accepted_at is not None
        assert stored_invitation.accepted_by_user_id is None


@pytest.mark.asyncio
async def test_accept_requires_matching_verified_email_and_keeps_token_usable(
    invitation_api_context,
) -> None:
    client, session_factory, current, owner, member, outsider, _, sender, _ = (
        invitation_api_context
    )
    group_id = await _create_group(session_factory, owner.id)
    created = await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": member.email, "role": "member"},
    )
    assert created.status_code == 202
    token = sender.invitations[-1]["token"]

    current["value"] = member
    unverified = await client.post(
        f"/api/v1/group-invitations/{token}/accept"
    )
    assert unverified.status_code == 403
    assert unverified.json()["detail"]["code"] == "invitation_email_mismatch"

    await _verify_user(session_factory, outsider)
    current["value"] = outsider
    mismatch = await client.post(f"/api/v1/group-invitations/{token}/accept")
    assert mismatch.status_code == 403
    assert mismatch.json()["detail"]["code"] == "invitation_email_mismatch"

    await _verify_user(session_factory, member)
    current["value"] = member
    accepted = await client.post(f"/api/v1/group-invitations/{token}/accept")
    assert accepted.status_code == 201


@pytest.mark.asyncio
async def test_expired_invitation_returns_gone(
    invitation_api_context,
) -> None:
    client, session_factory, current, owner, member, _, _, sender, _ = (
        invitation_api_context
    )
    group_id = await _create_group(session_factory, owner.id)
    await _verify_user(session_factory, member)
    await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": member.email, "role": "member"},
    )
    token = sender.invitations[-1]["token"]
    async with session_factory() as session:
        invitation = (
            await session.scalars(
                select(GroupInvitation).where(
                    GroupInvitation.token_hash == hash_token(token)
                )
            )
        ).one()
        invitation.created_at = datetime.now(UTC) - timedelta(days=2)
        invitation.expires_at = datetime.now(UTC) - timedelta(days=1)
        await session.commit()

    current["value"] = member
    response = await client.post(f"/api/v1/group-invitations/{token}/accept")
    assert response.status_code == 410
    assert response.json()["detail"]["code"] == "invitation_expired_or_used"


@pytest.mark.asyncio
async def test_accept_reactivates_departed_membership_in_place(
    invitation_api_context,
) -> None:
    client, session_factory, current, owner, _, _, former, sender, _ = (
        invitation_api_context
    )
    group_id = await _create_group(session_factory, owner.id)
    old_joined_at = datetime(2026, 1, 1, tzinfo=UTC)
    async with session_factory() as session:
        repository = GroupRepository(session)
        membership = await repository.add_member(
            group_id=group_id,
            user_id=former.id,
            role=GroupRole.member,
            joined_at=old_joined_at,
        )
        membership.left_at = datetime(2026, 2, 1, tzinfo=UTC)
        user = await session.get(User, former.id)
        assert user is not None
        user.is_email_verified = True
        await session.commit()
    former.is_email_verified = True

    await client.post(
        f"/api/v1/groups/{group_id}/invitations",
        json={"email": former.email, "role": "admin"},
    )
    token = sender.invitations[-1]["token"]
    current["value"] = former
    response = await client.post(f"/api/v1/group-invitations/{token}/accept")

    assert response.status_code == 201
    assert response.json()["member"]["role"] == "admin"
    async with session_factory() as session:
        memberships = list(
            (
                await session.scalars(
                    select(GroupMember).where(
                        GroupMember.group_id == group_id,
                        GroupMember.user_id == former.id,
                    )
                )
            ).all()
        )
        assert len(memberships) == 1
        assert memberships[0].left_at is None
        joined_at = memberships[0].joined_at
        if joined_at.tzinfo is None:
            joined_at = joined_at.replace(tzinfo=UTC)
        assert joined_at > old_joined_at
