import logging
import sys

import pytest
from fastapi.testclient import TestClient
from uvicorn.logging import AccessFormatter

from app.api.dependencies import get_rate_limiter
from app.api.routers.receipts import get_receipt_parser_service
from app.core.observability import (
    PROCESS_TIME_HEADER,
    REQUEST_ID_HEADER,
    PersonalDataRedactionFilter,
    redact_personal_data,
)
from app.core.rate_limit import NoOpRateLimiter
from app.main import app
from app.schemas import ReceiptParserRequest, ReceiptParserResponse


class ObservableReceiptParser:
    model_name = "test-model"

    async def parse(
        self,
        request: ReceiptParserRequest,
    ) -> ReceiptParserResponse:
        return ReceiptParserResponse(
            normalized_ocr_text=request.ocr_text,
            merchant="Test Market",
            total_amount_minor=1000,
            date="2026-08-03T00:00:00Z",
            category="Market",
            is_parse_successful=True,
            confidence_score=0.9,
            items=[],
        )


class UnexpectedReceiptParser:
    model_name = "test-model"

    async def parse(
        self,
        request: ReceiptParserRequest,
    ) -> ReceiptParserResponse:
        del request
        raise RuntimeError("unexpected parser failure")


@pytest.fixture(autouse=True)
def reset_dependency_overrides():
    app.dependency_overrides.clear()
    app.dependency_overrides[get_rate_limiter] = lambda: NoOpRateLimiter()
    yield
    app.dependency_overrides.clear()


def test_request_id_and_duration_are_returned_and_logged(caplog) -> None:
    request_id = "test-request-1234"
    caplog.set_level(logging.INFO, logger="app.request")

    with TestClient(app) as client:
        response = client.get(
            "/health",
            headers={REQUEST_ID_HEADER: request_id},
        )

    assert response.status_code == 200
    assert response.headers[REQUEST_ID_HEADER] == request_id
    assert float(response.headers[PROCESS_TIME_HEADER]) >= 0
    assert any(
        request_id in record.getMessage()
        and "status_code=200" in record.getMessage()
        and "duration_ms=" in record.getMessage()
        for record in caplog.records
    )


def test_invalid_request_id_is_replaced() -> None:
    with TestClient(app) as client:
        response = client.get(
            "/health",
            headers={REQUEST_ID_HEADER: "invalid request id!"},
        )

    generated = response.headers[REQUEST_ID_HEADER]
    assert generated != "invalid request id!"
    assert len(generated) == 32


def test_receipt_log_contains_request_id_duration_and_model(caplog) -> None:
    request_id = "receipt-request-1234"
    app.dependency_overrides[get_receipt_parser_service] = lambda: (
        ObservableReceiptParser()
    )
    caplog.set_level(logging.INFO, logger="app.receipts")

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/parse-receipt",
            headers={REQUEST_ID_HEADER: request_id},
            json={"ocr_text": "TEST MARKET TOPLAM 10,00 TL"},
        )

    assert response.status_code == 200
    messages = [record.getMessage() for record in caplog.records]
    assert any(
        request_id in message
        and "duration_ms=" in message
        and "model=test-model" in message
        and "outcome=success" in message
        for message in messages
    )


def test_unexpected_parser_exception_is_not_logged_as_success(caplog) -> None:
    request_id = "unexpected-parser-1234"
    app.dependency_overrides[get_receipt_parser_service] = lambda: (
        UnexpectedReceiptParser()
    )
    caplog.set_level(logging.INFO, logger="app.receipts")

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/parse-receipt",
            headers={REQUEST_ID_HEADER: request_id},
            json={"ocr_text": "TEST MARKET TOPLAM 10,00 TL"},
        )

    assert response.status_code == 500
    messages = [record.getMessage() for record in caplog.records]
    receipt_messages = [
        message for message in messages if "receipt_parse_completed" in message
    ]
    assert any("outcome=unexpected_error" in message for message in receipt_messages)
    assert all("outcome=success" not in message for message in receipt_messages)


def test_unhandled_exception_response_preserves_observability_headers() -> None:
    request_id = "unhandled-request-1234"
    app.dependency_overrides[get_receipt_parser_service] = lambda: (
        UnexpectedReceiptParser()
    )

    with TestClient(app) as client:
        response = client.post(
            "/api/v1/parse-receipt",
            headers={REQUEST_ID_HEADER: request_id},
            json={"ocr_text": "TEST MARKET TOPLAM 10,00 TL"},
        )

    assert response.status_code == 500
    assert response.json() == {"detail": "Internal server error."}
    assert response.headers[REQUEST_ID_HEADER] == request_id
    assert float(response.headers[PROCESS_TIME_HEADER]) >= 0


def test_personal_email_is_redacted_from_log_record() -> None:
    record = logging.LogRecord(
        name="app.test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="Login failed for %s",
        args=("personal.user+test@gmail.com",),
        exc_info=None,
    )

    PersonalDataRedactionFilter().filter(record)

    assert record.getMessage() == "Login failed for <redacted-email>"
    assert "personal.user" not in record.getMessage()


def test_redaction_preserves_uvicorn_access_log_arguments() -> None:
    record = logging.LogRecord(
        name="uvicorn.access",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg='%s - "%s %s HTTP/%s" %d',
        args=(
            "127.0.0.1:12345",
            "POST",
            "/api/v1/assistant/query?email=person@example.com",
            "1.1",
            200,
        ),
        exc_info=None,
    )

    PersonalDataRedactionFilter().filter(record)
    formatted = AccessFormatter().format(record)

    assert len(record.args) == 5
    assert "person@example.com" not in formatted
    assert "<redacted-email>" in formatted


def test_personal_email_is_redacted_from_exception_traceback() -> None:
    try:
        raise RuntimeError("SMTP failed for personal.user@gmail.com")
    except RuntimeError:
        record = logging.LogRecord(
            name="app.test",
            level=logging.ERROR,
            pathname=__file__,
            lineno=1,
            msg="Request failed",
            args=(),
            exc_info=sys.exc_info(),
        )

    PersonalDataRedactionFilter().filter(record)

    assert record.exc_info is None
    assert record.exc_text is not None
    assert "personal.user@gmail.com" not in record.exc_text
    assert "<redacted-email>" in record.exc_text


def test_redaction_removes_email_without_changing_safe_context() -> None:
    value = redact_personal_data(
        "request_id=req-123 email=person@example.com status=failed"
    )

    assert value == ("request_id=req-123 email=<redacted-email> status=failed")
