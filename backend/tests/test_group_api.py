import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_current_user
from app.core.database import Base, get_db_session
from app.main import app
from app.models import Group, GroupMember, GroupRole, User
from app.repositories.groups import GroupRepository


@pytest_asyncio.fixture
async def group_api_context():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )

    @event.listens_for(engine.sync_engine, "connect")
    def _enable_sqlite_foreign_keys(dbapi_connection, _connection_record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async with session_factory() as session:
        owner = User(email="owner@example.com", display_name="Grup Sahibi")
        member = User(email="member@example.com", display_name="Grup Üyesi")
        outsider = User(email="outsider@example.com", display_name="Dış Kullanıcı")
        former = User(email="former@example.com", display_name="Eski Üye")
        session.add_all([owner, member, outsider, former])
        await session.commit()

    current_user = {"value": owner}

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_current_user() -> User:
        return current_user["value"]

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_current_user

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield (
            client,
            session_factory,
            current_user,
            owner,
            member,
            outsider,
            former,
        )

    app.dependency_overrides.clear()
    await engine.dispose()


async def _create_group(
    session_factory,
    *,
    owner_id: uuid.UUID,
    name: str,
) -> uuid.UUID:
    async with session_factory() as session:
        group = await GroupRepository(session).create(
            name=name,
            created_by=owner_id,
        )
        await session.commit()
        return group.id


def _assert_error(response: httpx.Response, *, status_code: int, code: str) -> None:
    assert response.status_code == status_code
    assert response.json()["detail"]["code"] == code
    assert response.json()["detail"]["message"]


@pytest.mark.asyncio
async def test_group_endpoints_require_authentication(group_api_context) -> None:
    client, _, _, _, _, _, _ = group_api_context
    override = app.dependency_overrides.pop(get_current_user)
    try:
        response = await client.get("/api/v1/groups")
    finally:
        app.dependency_overrides[get_current_user] = override

    _assert_error(response, status_code=401, code="unauthorized")
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.asyncio
async def test_create_group_adds_current_user_as_owner_atomically(
    group_api_context,
) -> None:
    client, session_factory, _, owner, _, _, _ = group_api_context

    response = await client.post(
        "/api/v1/groups",
        json={
            "name": "  Ev Arkadaşları  ",
            "description": "Ortak ev masrafları",
            "currency": "try",
        },
    )

    assert response.status_code == 201
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["pragma"] == "no-cache"
    group = response.json()["group"]
    assert group["name"] == "Ev Arkadaşları"
    assert group["description"] == "Ortak ev masrafları"
    assert group["currency"] == "TRY"
    assert group["member_count"] == 1
    assert group["current_user_role"] == "owner"
    assert group["created_by"] == str(owner.id)
    assert group["created_at"].endswith("Z")
    assert group["members"] == [
        {
            "group_id": group["id"],
            "user_id": str(owner.id),
            "display_name": "Grup Sahibi",
            "role": "owner",
            "joined_at": group["members"][0]["joined_at"],
            "left_at": None,
        }
    ]
    assert "email" not in group["members"][0]

    async with session_factory() as session:
        stored_group = await session.get(Group, uuid.UUID(group["id"]))
        stored_membership = await session.get(
            GroupMember,
            (uuid.UUID(group["id"]), owner.id),
        )
    assert stored_group is not None
    assert stored_membership is not None
    assert stored_membership.role is GroupRole.owner


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {"name": "Geçerli", "description": None},
        {"name": "   ", "currency": "TRY"},
        {"name": "Geçerli", "currency": "USD"},
        {"name": "Geçerli", "currency": "TRY", "unexpected": True},
        {"name": "Geçerli", "description": "x" * 1001, "currency": "TRY"},
    ],
)
async def test_create_group_uses_contract_validation_error(
    group_api_context,
    payload: dict[str, object],
) -> None:
    client, _, _, _, _, _, _ = group_api_context

    response = await client.post("/api/v1/groups", json=payload)

    _assert_error(response, status_code=400, code="invalid_request")


@pytest.mark.asyncio
async def test_list_groups_rejects_invalid_archive_filter(group_api_context) -> None:
    client, _, _, _, _, _, _ = group_api_context

    response = await client.get(
        "/api/v1/groups",
        params={"include_archived": "not-a-boolean"},
    )

    _assert_error(response, status_code=400, code="invalid_request")


@pytest.mark.asyncio
async def test_list_groups_returns_only_active_memberships_and_filters_archived(
    group_api_context,
) -> None:
    (
        client,
        session_factory,
        _,
        owner,
        member,
        outsider,
        former,
    ) = group_api_context
    async with session_factory() as session:
        repository = GroupRepository(session)
        active = await repository.create(name="Aktif Grup", created_by=owner.id)
        await repository.add_member(group_id=active.id, user_id=member.id)
        former_membership = await repository.add_member(
            group_id=active.id,
            user_id=former.id,
        )
        former_membership.left_at = datetime.now(UTC)

        archived = await repository.create(
            name="Arşivlenmiş Grup",
            created_by=owner.id,
        )
        archived.archived_at = datetime.now(UTC)
        await repository.create(name="Yabancı Grup", created_by=outsider.id)

        left_group = await repository.create(
            name="Ayrıldığım Grup",
            created_by=outsider.id,
        )
        left_membership = await repository.add_member(
            group_id=left_group.id,
            user_id=owner.id,
        )
        left_membership.left_at = datetime.now(UTC)
        await session.commit()

    active_response = await client.get("/api/v1/groups")
    archived_response = await client.get(
        "/api/v1/groups",
        params={"include_archived": "true"},
    )

    assert active_response.status_code == 200
    active_groups = active_response.json()["groups"]
    assert [group["name"] for group in active_groups] == ["Aktif Grup"]
    assert active_groups[0]["member_count"] == 2
    assert active_groups[0]["current_user_role"] == "owner"
    assert {group["name"] for group in archived_response.json()["groups"]} == {
        "Aktif Grup",
        "Arşivlenmiş Grup",
    }


@pytest.mark.asyncio
async def test_group_detail_requires_active_membership(group_api_context) -> None:
    client, session_factory, current_user, owner, member, outsider, former = (
        group_api_context
    )
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Detay Grubu", created_by=owner.id)
        await repository.add_member(group_id=group.id, user_id=member.id)
        departed = await repository.add_member(group_id=group.id, user_id=former.id)
        departed.left_at = datetime.now(UTC)
        await session.commit()
        group_id = group.id

    current_user["value"] = member
    member_response = await client.get(f"/api/v1/groups/{group_id}")
    assert member_response.status_code == 200
    detail = member_response.json()["group"]
    assert detail["current_user_role"] == "member"
    assert detail["member_count"] == 2
    assert {item["display_name"] for item in detail["members"]} == {
        "Grup Sahibi",
        "Grup Üyesi",
    }

    current_user["value"] = outsider
    forbidden = await client.get(f"/api/v1/groups/{group_id}")
    _assert_error(forbidden, status_code=403, code="group_forbidden")

    current_user["value"] = former
    departed_response = await client.get(f"/api/v1/groups/{group_id}")
    _assert_error(departed_response, status_code=403, code="group_forbidden")

    missing = await client.get(f"/api/v1/groups/{uuid.uuid4()}")
    _assert_error(missing, status_code=404, code="group_not_found")
    malformed = await client.get("/api/v1/groups/not-a-uuid")
    _assert_error(malformed, status_code=404, code="group_not_found")


@pytest.mark.asyncio
async def test_only_owner_can_update_group_and_clear_description(
    group_api_context,
) -> None:
    client, session_factory, current_user, owner, member, admin, _ = (
        group_api_context
    )
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(
            name="Eski Ad",
            description="Silinecek açıklama",
            created_by=owner.id,
        )
        await repository.add_member(group_id=group.id, user_id=member.id)
        await repository.add_member(
            group_id=group.id,
            user_id=admin.id,
            role=GroupRole.admin,
        )
        await session.commit()
        group_id = group.id

    for unauthorized_user in (member, admin):
        current_user["value"] = unauthorized_user
        forbidden = await client.patch(
            f"/api/v1/groups/{group_id}",
            json={"name": "Yetkisiz Değişiklik"},
        )
        _assert_error(forbidden, status_code=403, code="group_forbidden")

    current_user["value"] = owner
    updated = await client.patch(
        f"/api/v1/groups/{group_id}",
        json={"name": "  Yeni Ad  ", "description": None},
    )
    assert updated.status_code == 200
    detail = updated.json()["group"]
    assert detail["name"] == "Yeni Ad"
    assert detail["description"] is None
    assert detail["current_user_role"] == "owner"
    assert len(detail["members"]) == 3

    async with session_factory() as session:
        stored = await session.get(Group, group_id)
    assert stored is not None
    assert stored.name == "Yeni Ad"
    assert stored.description is None


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"name": None},
        {"name": "   "},
        {"description": "x" * 1001},
        {"currency": "TRY"},
    ],
)
async def test_update_group_rejects_invalid_payloads(
    group_api_context,
    payload: dict[str, object],
) -> None:
    client, session_factory, _, owner, _, _, _ = group_api_context
    group_id = await _create_group(
        session_factory,
        owner_id=owner.id,
        name="Değişmeyecek Grup",
    )

    response = await client.patch(f"/api/v1/groups/{group_id}", json=payload)

    _assert_error(response, status_code=400, code="invalid_request")


@pytest.mark.asyncio
async def test_archive_is_owner_only_soft_and_idempotent(group_api_context) -> None:
    client, session_factory, current_user, owner, member, _, _ = group_api_context
    async with session_factory() as session:
        repository = GroupRepository(session)
        group = await repository.create(name="Arşivlenecek", created_by=owner.id)
        await repository.add_member(group_id=group.id, user_id=member.id)
        await session.commit()
        group_id = group.id

    current_user["value"] = member
    forbidden = await client.delete(f"/api/v1/groups/{group_id}")
    _assert_error(forbidden, status_code=403, code="group_forbidden")

    current_user["value"] = owner
    archived = await client.delete(f"/api/v1/groups/{group_id}")
    assert archived.status_code == 204
    assert archived.content == b""

    async with session_factory() as session:
        stored = await session.get(Group, group_id)
        assert stored is not None
        first_archived_at = stored.archived_at
        assert first_archived_at is not None

    active_list = await client.get("/api/v1/groups")
    archived_list = await client.get(
        "/api/v1/groups",
        params={"include_archived": "true"},
    )
    assert active_list.json() == {"groups": []}
    assert [item["id"] for item in archived_list.json()["groups"]] == [
        str(group_id)
    ]

    repeated = await client.delete(f"/api/v1/groups/{group_id}")
    assert repeated.status_code == 204
    async with session_factory() as session:
        stored = await session.get(Group, group_id)
        assert stored is not None
        assert stored.archived_at == first_archived_at
