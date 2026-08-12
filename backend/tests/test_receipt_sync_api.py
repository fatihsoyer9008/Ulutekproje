import uuid

import pytest


@pytest.mark.asyncio
async def test_receipt_sync_returns_stable_cloud_ids(group_api_context) -> None:
    client, _, _, _, _, _, _ = group_api_context
    client_record_id = uuid.uuid4()
    payload = {
        "client_record_id": str(client_record_id),
        "merchant_name": "Mahalle Market",
        "total_amount_in_minor": 1_250,
        "currency": "TRY",
        "receipt_date": "2026-08-12T12:00:00Z",
        "category": "market",
        "client_created_at": "2026-08-12T12:00:00Z",
        "client_updated_at": "2026-08-12T12:01:00Z",
        "line_items": [
            {
                "position": 0,
                "name": "Süt",
                "total_amount_in_minor": 750,
                "quantity_milli": 1000,
                "unit_price_in_minor": 750,
            },
            {
                "position": 1,
                "name": "Ekmek",
                "total_amount_in_minor": 500,
            },
        ],
    }
    headers = {"X-Installation-ID": "test-installation-1234"}

    first = await client.post("/api/v1/receipts/sync", json=payload, headers=headers)
    replay = await client.post("/api/v1/receipts/sync", json=payload, headers=headers)

    assert first.status_code == 200
    assert replay.status_code == 200
    assert replay.json() == first.json()
    body = first.json()
    assert body["total_amount_in_minor"] == 1_250
    assert [item["position"] for item in body["line_items"]] == [0, 1]
    assert all(item["receipt_line_item_id"] for item in body["line_items"])
