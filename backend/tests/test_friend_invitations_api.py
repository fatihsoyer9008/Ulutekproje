import logging
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
from app.models import ExpenseSplitType, FriendInvitation, User
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository
from tests.test_group_api import group_api_context

__all__ = ("group_api_context",)


@dataclass
class CapturingFriendInvitationEmailSender:
    invitations: list[dict[str, str]] = field(default_factory=list)

    async def send_friend_invitation(
        self,
        *,
        email: str,
        token: str,
        inviter_display_name: str,
    ) -> None:
        self.invitations.append(
            {
                "email": email,
                "token": token,
                "inviter_display_name": inviter_display_name,
            }
        )


class FailingFriendInvitationEmailSender(CapturingFriendInvitationEmailSender):
    async def send_friend_invitation(
        self,
        *,
        email: str,
        token: str,
        inviter_display_name: str,
    ) -> None:
        del email, token, inviter_display_name
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
async def friend_invitation_api_context(group_api_context):
    sender = CapturingFriendInvitationEmailSender()
    limiter = RecordingRateLimiter()
    app.dependency_overrides[get_email_sender] = lambda: sender
    app.dependency_overrides[get_rate_limiter] = lambda: limiter
    yield (*group_api_context, sender, limiter)


async def _verify_user(session_factory, user: User) -> None:
    async with session_factory() as session:
        stored_user = await session.get(User, user.id)
        assert stored_user is not None
        stored_user.is_email_verified = True
        await session.commit()
    user.is_email_verified = True


@pytest.mark.asyncio
async def test_create_invitation_stores_only_hash_with_24_hour_expiry_and_limits(
    friend_invitation_api_context,
) -> None:
    client, session_factory, _, owner, _, _, _, sender, limiter = (
        friend_invitation_api_context
    )

    response = await client.post(
        "/api/v1/friends/invitations",
        json={"email": "  NEW.FRIEND@Example.COM "},
    )

    assert response.status_code == 202
    assert response.json() == {"status": "request_received"}
    assert len(sender.invitations) == 1
    delivered = sender.invitations[0]
    assert delivered["email"] == "new.friend@example.com"
    assert delivered["inviter_display_name"] == (owner.display_name or owner.email)

    async with session_factory() as session:
        invitation = (await session.scalars(select(FriendInvitation))).one()
        assert invitation.invited_email == "new.friend@example.com"
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
        "friend-invitation-user-hourly",
        "friend-invitation-email-daily",
    ]
    assert [identifier for _, identifier in limiter.calls] == [
        f"user:{owner.id}",
        "email:new.friend@example.com",
    ]


@pytest.mark.asyncio
async def test_creation_response_does_not_enumerate_account_state(
    friend_invitation_api_context,
) -> None:
    client, _, _, owner, member, _, _, sender, _ = friend_invitation_api_context

    responses = [
        await client.post(
            "/api/v1/friends/invitations",
            json={"email": email},
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
async def test_invitation_rate_limit_uses_public_error_contract(
    friend_invitation_api_context,
) -> None:
    client, session_factory, _, _, _, _, _, sender, limiter = (
        friend_invitation_api_context
    )
    limiter.reject = True

    response = await client.post(
        "/api/v1/friends/invitations",
        json={"email": "limited@example.com"},
    )

    assert response.status_code == 429
    assert response.json()["detail"]["code"] == "invitation_rate_limited"
    assert response.headers["retry-after"] == "60"
    assert sender.invitations == []
    async with session_factory() as session:
        assert await session.scalar(select(func.count(FriendInvitation.id))) == 0


@pytest.mark.asyncio
async def test_delivery_failure_keeps_general_response_without_logging_email(
    friend_invitation_api_context,
    caplog,
) -> None:
    client, session_factory, _, _, _, _, _, _, _ = friend_invitation_api_context
    sender = FailingFriendInvitationEmailSender()
    app.dependency_overrides[get_email_sender] = lambda: sender
    raw_email = "private.invitee@example.com"
    caplog.set_level(logging.ERROR, logger="app.api.routers.friend_invitations")

    response = await client.post(
        "/api/v1/friends/invitations",
        json={"email": raw_email},
    )

    assert response.status_code == 202
    assert response.json() == {"status": "request_received"}
    assert raw_email not in caplog.text
    assert "email_hash=" in caplog.text
    async with session_factory() as session:
        assert await session.scalar(select(func.count(FriendInvitation.id))) == 1


@pytest.mark.asyncio
async def test_accept_requires_auth_and_unknown_token_returns_gone(
    friend_invitation_api_context,
) -> None:
    client, _, _, _, _, _, _, _, _ = friend_invitation_api_context
    override = app.dependency_overrides.pop(get_current_user)
    try:
        unauthorized = await client.post(
            "/api/v1/friend-invitations/unknown-token/accept"
        )
    finally:
        app.dependency_overrides[get_current_user] = override

    assert unauthorized.status_code == 401
    assert unauthorized.json()["detail"]["code"] == "unauthorized"

    gone = await client.post("/api/v1/friend-invitations/unknown-token/accept")
    assert gone.status_code == 410
    assert gone.json()["detail"]["code"] == "invitation_expired_or_used"


@pytest.mark.asyncio
async def test_accept_invitation_creates_friend_entry_and_is_one_time(
    friend_invitation_api_context,
) -> None:
    client, session_factory, current, owner, member, _, _, sender, _ = (
        friend_invitation_api_context
    )
    await _verify_user(session_factory, member)
    created = await client.post(
        "/api/v1/friends/invitations",
        json={"email": member.email},
    )
    assert created.status_code == 202
    token = sender.invitations[-1]["token"]
    current["value"] = member

    accepted = await client.post(f"/api/v1/friend-invitations/{token}/accept")

    assert accepted.status_code == 201
    friend = accepted.json()["friend"]
    assert friend["user_id"] == str(owner.id)
    assert friend["net_amount_in_minor"] == 0
    assert friend["status"] == "settled_up"
    assert friend["shared_group_ids"] == []
    direct_group_id = friend["direct_group_id"]

    replay = await client.post(f"/api/v1/friend-invitations/{token}/accept")
    assert replay.status_code == 410
    assert replay.json()["detail"]["code"] == "invitation_expired_or_used"

    async with session_factory() as session:
        invitation = (
            await session.scalars(
                select(FriendInvitation).where(
                    FriendInvitation.token_hash == hash_token(token)
                )
            )
        ).one()
        assert invitation.accepted_at is not None
        assert invitation.accepted_by_user_id == member.id

        direct_group = await GroupRepository(session).get_direct_group(
            owner.id, member.id
        )
        assert direct_group is not None
        assert str(direct_group.id) == direct_group_id


@pytest.mark.asyncio
async def test_accept_requires_matching_verified_email_and_keeps_token_usable(
    friend_invitation_api_context,
) -> None:
    client, session_factory, current, _, member, outsider, _, sender, _ = (
        friend_invitation_api_context
    )
    created = await client.post(
        "/api/v1/friends/invitations",
        json={"email": member.email},
    )
    assert created.status_code == 202
    token = sender.invitations[-1]["token"]

    current["value"] = member
    unverified = await client.post(f"/api/v1/friend-invitations/{token}/accept")
    assert unverified.status_code == 403
    assert unverified.json()["detail"]["code"] == "invitation_email_mismatch"

    await _verify_user(session_factory, outsider)
    current["value"] = outsider
    mismatch = await client.post(f"/api/v1/friend-invitations/{token}/accept")
    assert mismatch.status_code == 403
    assert mismatch.json()["detail"]["code"] == "invitation_email_mismatch"

    await _verify_user(session_factory, member)
    current["value"] = member
    accepted = await client.post(f"/api/v1/friend-invitations/{token}/accept")
    assert accepted.status_code == 201


@pytest.mark.asyncio
async def test_expired_invitation_returns_gone(
    friend_invitation_api_context,
) -> None:
    client, session_factory, current, _, member, _, _, sender, _ = (
        friend_invitation_api_context
    )
    await _verify_user(session_factory, member)
    await client.post(
        "/api/v1/friends/invitations",
        json={"email": member.email},
    )
    token = sender.invitations[-1]["token"]
    async with session_factory() as session:
        invitation = (
            await session.scalars(
                select(FriendInvitation).where(
                    FriendInvitation.token_hash == hash_token(token)
                )
            )
        ).one()
        invitation.created_at = datetime.now(UTC) - timedelta(days=2)
        invitation.expires_at = datetime.now(UTC) - timedelta(days=1)
        await session.commit()

    current["value"] = member
    response = await client.post(f"/api/v1/friend-invitations/{token}/accept")
    assert response.status_code == 410
    assert response.json()["detail"]["code"] == "invitation_expired_or_used"


@pytest.mark.asyncio
async def test_accept_own_invitation_rejects_self_friending(
    friend_invitation_api_context,
) -> None:
    client, session_factory, current, owner, _, _, _, sender, _ = (
        friend_invitation_api_context
    )
    await _verify_user(session_factory, owner)
    await client.post(
        "/api/v1/friends/invitations",
        json={"email": owner.email},
    )
    token = sender.invitations[-1]["token"]
    current["value"] = owner

    response = await client.post(f"/api/v1/friend-invitations/{token}/accept")

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "cannot_friend_self"


@pytest.mark.asyncio
async def test_accept_reuses_existing_direct_group_with_prior_balance(
    friend_invitation_api_context,
) -> None:
    client, session_factory, current, owner, member, _, _, sender, _ = (
        friend_invitation_api_context
    )
    await _verify_user(session_factory, member)

    async with session_factory() as session:
        groups = GroupRepository(session)
        direct_group = await groups.create(
            name="", created_by=owner.id, currency="TRY", is_direct=True
        )
        await groups.add_member(group_id=direct_group.id, user_id=member.id)
        await GroupExpenseRepository(session).create(
            group_id=direct_group.id,
            payer_user_id=owner.id,
            title="Kahve",
            expense_date=datetime.now(UTC),
            total_amount_in_minor=2_000,
            currency="TRY",
            split_type=ExpenseSplitType.equal,
            shares=[(owner.id, 1_000), (member.id, 1_000)],
        )
        await session.commit()
        existing_group_id = direct_group.id

    await client.post(
        "/api/v1/friends/invitations",
        json={"email": member.email},
    )
    token = sender.invitations[-1]["token"]
    current["value"] = member

    response = await client.post(f"/api/v1/friend-invitations/{token}/accept")

    assert response.status_code == 201
    friend = response.json()["friend"]
    assert friend["direct_group_id"] == str(existing_group_id)
    assert friend["net_amount_in_minor"] == -1_000
    assert friend["status"] == "you_owe"

    async with session_factory() as session:
        assert (
            await session.scalar(select(func.count(FriendInvitation.id))) == 1
        )
