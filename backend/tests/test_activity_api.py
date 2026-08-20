import pytest

from app.repositories.groups import GroupRepository
from tests.test_settlement_api import settlement_api_context  # noqa: F401


@pytest.mark.asyncio
async def test_expense_creation_appears_in_activity_with_per_viewer_impact(
    group_api_context,
) -> None:
    client, session_factory, current, owner, member, _, _ = group_api_context
    async with session_factory() as session:
        group = await GroupRepository(session).create(name="Tatil", created_by=owner.id)
        await GroupRepository(session).add_member(
            group_id=group.id, user_id=member.id
        )
        await session.commit()
        group_id = group.id

    current["value"] = owner
    response = await client.post(
        f"/api/v1/groups/{group_id}/expenses",
        json={
            "title": "Akşam yemeği",
            "expense_date": "2026-08-12T20:00:00Z",
            "total_amount_in_minor": 10_000,
            "currency": "TRY",
            "receipt_id": None,
            "payer_user_id": str(owner.id),
            "split": {
                "type": "equal",
                "member_ids": [str(owner.id), str(member.id)],
            },
        },
        headers={"Idempotency-Key": "dinner-1"},
    )
    assert response.status_code == 201

    owner_feed = await client.get("/api/v1/activity")
    assert owner_feed.status_code == 200
    owner_items = owner_feed.json()["items"]
    assert len(owner_items) == 1
    item = owner_items[0]
    assert item["type"] == "expense_created"
    assert item["actor"]["user_id"] == str(owner.id)
    assert item["group"]["id"] == str(group_id)
    assert item["group"]["is_direct"] is False
    assert item["expense_details"]["title"] == "Akşam yemeği"
    assert item["expense_details"]["total_amount_in_minor"] == 10_000
    # Owner paid 10000 and owes half (5000) -> owed back 5000.
    assert item["impact"] == {"status": "you_are_owed", "amount_in_minor": 5000}

    current["value"] = member
    member_feed = await client.get("/api/v1/activity")
    member_item = member_feed.json()["items"][0]
    assert member_item["impact"] == {"status": "you_owe", "amount_in_minor": 5000}


@pytest.mark.asyncio
async def test_settlement_creation_appears_in_activity_for_the_recipient(
    settlement_api_context,  # noqa: F811
) -> None:
    context = settlement_api_context
    client = context["client"]
    current = context["current_user"]
    owner = context["owner"]
    member = context["member"]
    group_id = context["group_id"]

    current["value"] = member
    response = await client.post(
        f"/api/v1/groups/{group_id}/settlements",
        json={
            "from_user_id": str(member.id),
            "to_user_id": str(owner.id),
            "amount_in_minor": 2500,
            "currency": "TRY",
            "settled_at": "2026-08-13T09:00:00Z",
            "note": None,
        },
        headers={"Idempotency-Key": "settle-1"},
    )
    assert response.status_code == 201

    current["value"] = owner
    feed = await client.get("/api/v1/activity")
    items = feed.json()["items"]
    assert len(items) == 1
    assert items[0]["type"] == "settlement_created"
    assert items[0]["settlement_details"]["amount_in_minor"] == 2500
    assert items[0]["impact"] == {"status": "you_get_back", "amount_in_minor": 2500}

    current["value"] = member
    payer_feed = await client.get("/api/v1/activity")
    assert payer_feed.json()["items"][0]["impact"] is None


@pytest.mark.asyncio
async def test_member_added_appears_in_activity(group_api_context) -> None:
    client, session_factory, current, owner, member, outsider, _ = group_api_context
    async with session_factory() as session:
        group = await GroupRepository(session).create(name="Tatil", created_by=owner.id)
        await session.commit()
        group_id = group.id

    current["value"] = owner
    response = await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(member.id), "role": "member"},
    )
    assert response.status_code == 201

    feed = await client.get("/api/v1/activity")
    items = feed.json()["items"]
    assert len(items) == 1
    assert items[0]["type"] == "member_joined"
    assert items[0]["member_details"]["user_id"] == str(member.id)
    assert items[0]["impact"] is None
    del outsider


@pytest.mark.asyncio
async def test_activity_feed_is_scoped_to_the_users_groups(group_api_context) -> None:
    client, session_factory, current, owner, member, outsider, _ = group_api_context
    async with session_factory() as session:
        group = await GroupRepository(session).create(name="Tatil", created_by=owner.id)
        await session.commit()
        group_id = group.id

    current["value"] = owner
    await client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_id": str(member.id), "role": "member"},
    )

    current["value"] = outsider
    feed = await client.get("/api/v1/activity")
    assert feed.json() == {"items": [], "next_cursor": None}


@pytest.mark.asyncio
async def test_activity_feed_paginates_with_cursor(group_api_context) -> None:
    client, session_factory, current, owner, member, _, _ = group_api_context
    async with session_factory() as session:
        group = await GroupRepository(session).create(name="Tatil", created_by=owner.id)
        await GroupRepository(session).add_member(
            group_id=group.id, user_id=member.id
        )
        await session.commit()
        group_id = group.id

    current["value"] = owner
    for index in range(5):
        response = await client.post(
            f"/api/v1/groups/{group_id}/expenses",
            json={
                "title": f"Masraf {index}",
                "expense_date": "2026-08-12T20:00:00Z",
                "total_amount_in_minor": 1000,
                "currency": "TRY",
                "receipt_id": None,
                "payer_user_id": str(owner.id),
                "split": {
                    "type": "equal",
                    "member_ids": [str(owner.id), str(member.id)],
                },
            },
            headers={"Idempotency-Key": f"expense-{index}"},
        )
        assert response.status_code == 201

    first_page = await client.get("/api/v1/activity", params={"limit": 3})
    assert first_page.status_code == 200
    first_body = first_page.json()
    assert len(first_body["items"]) == 3
    assert first_body["next_cursor"] is not None

    second_page = await client.get(
        "/api/v1/activity",
        params={"limit": 3, "before": first_body["next_cursor"]},
    )
    second_body = second_page.json()
    assert len(second_body["items"]) == 2
    assert second_body["next_cursor"] is None

    first_ids = {item["id"] for item in first_body["items"]}
    second_ids = {item["id"] for item in second_body["items"]}
    assert first_ids.isdisjoint(second_ids)
