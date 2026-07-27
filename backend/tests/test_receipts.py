from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_parse_receipt_returns_minor_unit_integers() -> None:
    response = client.post("/api/v1/parse-receipt", json={"file_name": "market-fisi.jpg"})

    assert response.status_code == 200
    payload = response.json()
    assert payload["currency"] == "TRY"
    assert payload["total_minor"] == 32760
    assert isinstance(payload["total_minor"], int)
    assert isinstance(payload["items"][0]["unit_price_minor"], int)
    assert "total" not in payload


def test_parse_receipt_rejects_unknown_input_fields() -> None:
    response = client.post("/api/v1/parse-receipt", json={"amount": 327.60})

    assert response.status_code == 422

