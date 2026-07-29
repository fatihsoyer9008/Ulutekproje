from fastapi.testclient import TestClient

from app.main import app, get_receipt_parser_service
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import ReceiptParserError


class StubReceiptParser:
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        assert request.ocr_text == "MİGROS TOPLAM 220,50 TL"
        return ReceiptParserResponse(
            normalized_ocr_text="MİGROS\nTOPLAM 220,50 TL",
            merchant="MİGROS TİCARET A.Ş.",
            total_amount_minor=22050,
            currency="TRY",
            date="2026-07-25T14:30:00Z",
            category="Market",
            confidence_score=0.92,
            is_parse_successful=True,
            items=[],
        )


class FailingReceiptParser:
    async def parse(self, request: ReceiptParserRequest) -> ReceiptParserResponse:
        del request
        raise ReceiptParserError("provider failed")


def test_health_check() -> None:
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_parse_receipt_returns_valid_minor_unit_response() -> None:
    app.dependency_overrides[get_receipt_parser_service] = StubReceiptParser
    try:
        with TestClient(app) as client:
            response = client.post(
                "/api/v1/parse-receipt",
                json={"ocr_text": "  MİGROS TOPLAM 220,50 TL  "},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {
        "normalized_ocr_text": "MİGROS\nTOPLAM 220,50 TL",
        "merchant": "MİGROS TİCARET A.Ş.",
        "total_amount_minor": 22050,
        "currency": "TRY",
        "date": "2026-07-25T14:30:00Z",
        "category": "Market",
        "confidence_score": 0.92,
        "is_parse_successful": True,
        "items": [],
    }


def test_parse_receipt_rejects_blank_ocr_text() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/parse-receipt",
            json={"ocr_text": "   "},
        )

    assert response.status_code == 422


def test_parse_receipt_maps_provider_error_to_bad_gateway() -> None:
    app.dependency_overrides[get_receipt_parser_service] = FailingReceiptParser
    try:
        with TestClient(app) as client:
            response = client.post(
                "/api/v1/parse-receipt",
                json={"ocr_text": "GEÇERLİ FİŞ METNİ"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 502
    assert response.json() == {
        "detail": "Fiş metni yapay zekâ servisi tarafından ayrıştırılamadı"
    }
