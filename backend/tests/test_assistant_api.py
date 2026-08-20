import uuid
from collections.abc import AsyncIterator
from datetime import UTC, date, datetime

import httpx
import pytest
import pytest_asyncio
from fastapi import Depends, HTTPException
from pydantic import SecretStr
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.dependencies import get_current_user, get_rate_limiter
from app.api.routers.assistant import get_assistant_model_service
from app.assistant_schemas import (
    AssistantAnswerPayload,
    AssistantFinancialSummary,
    AssistantPeriodPlan,
)
from app.core.config import settings
from app.core.database import Base, get_db_session
from app.core.rate_limit import NoOpRateLimiter
from app.main import app
from app.models.cloud_transaction import CloudTransaction
from app.models.user import User
from app.services.assistant_service import AssistantProviderError


class StubAssistantModel:
    model_name = "stub-assistant"

    def __init__(
        self,
        session_state: dict[str, AsyncSession | None] | None = None,
    ) -> None:
        self.summaries: list[AssistantFinancialSummary] = []
        self.session_state = session_state

    def _assert_no_open_db_transaction(self) -> None:
        if self.session_state is None:
            return

        session = self.session_state["value"]
        assert session is not None
        assert not session.in_transaction()

    async def plan_period(
        self,
        *,
        question: str,
        timezone_name: str,
        current_local_datetime: datetime,
    ) -> AssistantPeriodPlan:
        self._assert_no_open_db_transaction()
        assert question == "Bu ay ne harcadım?"
        assert timezone_name == "Europe/Istanbul"
        assert current_local_datetime.tzinfo is not None
        return AssistantPeriodPlan(
            start_date=date(2026, 8, 1),
            end_date_exclusive=date(2026, 9, 1),
        )

    async def generate_answer(
        self,
        *,
        question: str,
        summary: AssistantFinancialSummary,
    ) -> AssistantAnswerPayload:
        self._assert_no_open_db_transaction()
        assert question == "Bu ay ne harcadım?"
        self.summaries.append(summary)
        return AssistantAnswerPayload(
            answer="Ağustos ayında toplam 125,00 TL harcadın."
        )


class FailingAssistantModel(StubAssistantModel):
    model_name = "failing-assistant"

    async def plan_period(
        self,
        *,
        question: str,
        timezone_name: str,
        current_local_datetime: datetime,
    ) -> AssistantPeriodPlan:
        del question, timezone_name, current_local_datetime
        raise AssistantProviderError("simulated provider failure")


def test_assistant_provider_uses_dedicated_api_key(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "assistant_enabled", True)
    monkeypatch.setattr(
        settings,
        "assistant_gemini_api_key",
        SecretStr("assistant-only-key"),
    )
    monkeypatch.setattr(settings, "gemini_api_key", SecretStr("receipt-only-key"))

    service = get_assistant_model_service()

    assert service._api_key == "assistant-only-key"


def test_assistant_provider_does_not_fallback_to_receipt_key(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "assistant_enabled", True)
    monkeypatch.setattr(settings, "assistant_gemini_api_key", None)
    monkeypatch.setattr(settings, "gemini_api_key", SecretStr("receipt-only-key"))

    with pytest.raises(HTTPException) as exc_info:
        get_assistant_model_service()

    assert exc_info.value.status_code == 503
    assert exc_info.value.detail == "Finans asistanı şu anda kullanılamıyor."


def _transaction(
    *,
    user_id: uuid.UUID,
    transaction_type: str,
    amount_in_minor: int,
    transaction_date: datetime,
    category: str,
    merchant_name: str | None,
    deleted_at: datetime | None = None,
) -> CloudTransaction:
    return CloudTransaction(
        id=uuid.uuid4(),
        user_id=user_id,
        client_record_id=uuid.uuid4(),
        installation_id_hash="a" * 64,
        transaction_type=transaction_type,
        amount_in_minor=amount_in_minor,
        category=category,
        transaction_date=transaction_date,
        merchant_name=merchant_name,
        source="manual",
        raw_ocr_text=None,
        note=None,
        client_created_at=transaction_date,
        client_updated_at=transaction_date,
        created_at=transaction_date,
        updated_at=transaction_date,
        deleted_at=deleted_at,
    )


async def _grant_assistant_consent(client: httpx.AsyncClient) -> None:
    response = await client.put(
        "/api/v1/assistant/consent",
        json={
            "accepted": True,
            "consent_version": settings.assistant_consent_version,
        },
    )

    assert response.status_code == 200
    assert response.json()["consent_granted"] is True


@pytest_asyncio.fixture
async def assistant_context(
    monkeypatch: pytest.MonkeyPatch,
) -> AsyncIterator[tuple[httpx.AsyncClient, StubAssistantModel]]:
    monkeypatch.setattr(settings, "assistant_enabled", True)
    monkeypatch.setattr(settings, "assistant_max_period_days", 3660)

    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async with session_factory() as session:
        first_user = User(email="assistant-first@example.com")
        second_user = User(email="assistant-second@example.com")
        session.add_all([first_user, second_user])
        await session.flush()

        august_expense = datetime(2026, 8, 3, 9, 0, tzinfo=UTC)
        august_income = datetime(2026, 8, 1, 8, 0, tzinfo=UTC)
        session.add_all(
            [
                _transaction(
                    user_id=first_user.id,
                    transaction_type="expense",
                    amount_in_minor=12500,
                    transaction_date=august_expense,
                    category="Market",
                    merchant_name="Test Market",
                ),
                _transaction(
                    user_id=first_user.id,
                    transaction_type="income",
                    amount_in_minor=50000,
                    transaction_date=august_income,
                    category="Maaş",
                    merchant_name=None,
                ),
                _transaction(
                    user_id=first_user.id,
                    transaction_type="expense",
                    amount_in_minor=999999,
                    transaction_date=august_expense,
                    category="Silinmiş",
                    merchant_name="Deleted Merchant",
                    deleted_at=august_expense,
                ),
                _transaction(
                    user_id=first_user.id,
                    transaction_type="expense",
                    amount_in_minor=3333,
                    transaction_date=datetime(
                        2026,
                        7,
                        15,
                        10,
                        0,
                        tzinfo=UTC,
                    ),
                    category="Temmuz",
                    merchant_name="July Merchant",
                ),
                _transaction(
                    user_id=second_user.id,
                    transaction_type="expense",
                    amount_in_minor=77777,
                    transaction_date=august_expense,
                    category="Other User",
                    merchant_name="Other Merchant",
                ),
            ]
        )
        await session.commit()

    first_user_id = first_user.id
    session_state: dict[str, AsyncSession | None] = {"value": None}
    model = StubAssistantModel(session_state)

    async def override_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            session_state["value"] = session
            try:
                yield session
            finally:
                session_state["value"] = None

    async def override_current_user(
        db: AsyncSession = Depends(get_db_session),
    ) -> User:
        current_user = await db.get(User, first_user_id)
        assert current_user is not None
        return current_user

    async def override_limiter() -> NoOpRateLimiter:
        return NoOpRateLimiter()

    app.dependency_overrides[get_db_session] = override_db
    app.dependency_overrides[get_current_user] = override_current_user
    app.dependency_overrides[get_rate_limiter] = override_limiter
    app.dependency_overrides[get_assistant_model_service] = lambda: model

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield client, model

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_assistant_rejects_query_without_current_consent(
    assistant_context,
) -> None:
    client, model = assistant_context

    response = await client.post(
        "/api/v1/assistant/query",
        json={
            "question": "Bu ay ne harcadım?",
            "timezone": "Europe/Istanbul",
        },
    )

    assert response.status_code == 403
    assert response.json() == {
        "detail": "Finans asistanını kullanmak için veri işleme izni gereklidir."
    }
    assert model.summaries == []


@pytest.mark.asyncio
async def test_assistant_rejects_query_after_consent_is_revoked(
    assistant_context,
) -> None:
    client, model = assistant_context
    await _grant_assistant_consent(client)

    revoke_response = await client.put(
        "/api/v1/assistant/consent",
        json={
            "accepted": False,
            "consent_version": settings.assistant_consent_version,
        },
    )

    assert revoke_response.status_code == 200
    assert revoke_response.json()["consent_granted"] is False
    assert revoke_response.json()["consent_revoked_at"] is not None

    query_response = await client.post(
        "/api/v1/assistant/query",
        json={
            "question": "Bu ay ne harcadım?",
            "timezone": "Europe/Istanbul",
        },
    )

    assert query_response.status_code == 403
    assert query_response.json() == {
        "detail": "Finans asistanını kullanmak için veri işleme izni gereklidir."
    }
    assert model.summaries == []


@pytest.mark.asyncio
async def test_assistant_uses_only_current_users_active_period_data(
    assistant_context,
) -> None:
    client, model = assistant_context
    await _grant_assistant_consent(client)

    response = await client.post(
        "/api/v1/assistant/query",
        json={
            "question": "Bu ay ne harcadım?",
            "timezone": "Europe/Istanbul",
        },
    )

    assert response.status_code == 200
    assert response.headers["Cache-Control"] == "no-store"
    assert response.json()["answer"] == ("Ağustos ayında toplam 125,00 TL harcadın.")
    assert response.json()["period_start"] == "2026-08-01"
    assert response.json()["period_end_exclusive"] == "2026-09-01"
    assert response.json()["currency"] == "TRY"
    assert response.json()["disclaimer"] == ("Bu bir yatırım tavsiyesi değildir.")

    assert len(model.summaries) == 1
    summary = model.summaries[0]
    assert summary.expense_total_in_minor == 12500
    assert summary.income_total_in_minor == 50000
    assert summary.transaction_count == 2
    assert [(item.category, item.total_in_minor) for item in summary.categories] == [
        ("Market", 12500)
    ]
    assert [item.merchant_name for item in summary.merchants] == ["Test Market"]


@pytest.mark.asyncio
async def test_assistant_requires_authentication(assistant_context) -> None:
    client, _ = assistant_context
    override = app.dependency_overrides.pop(get_current_user)

    try:
        response = await client.post(
            "/api/v1/assistant/query",
            json={
                "question": "Bu ay ne harcadım?",
                "timezone": "Europe/Istanbul",
            },
        )
    finally:
        app.dependency_overrides[get_current_user] = override

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_assistant_rejects_invalid_timezone(assistant_context) -> None:
    client, _ = assistant_context

    response = await client.post(
        "/api/v1/assistant/query",
        json={
            "question": "Bu ay ne harcadım?",
            "timezone": "Invalid/Timezone",
        },
    )

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_assistant_maps_provider_failure_to_bad_gateway(
    assistant_context,
) -> None:
    client, _ = assistant_context
    await _grant_assistant_consent(client)
    app.dependency_overrides[get_assistant_model_service] = lambda: (
        FailingAssistantModel()
    )

    response = await client.post(
        "/api/v1/assistant/query",
        json={
            "question": "Bu ay ne harcadım?",
            "timezone": "Europe/Istanbul",
        },
    )

    assert response.status_code == 502
    assert response.json() == {
        "detail": "Finans asistanı yanıt oluşturamadı. Lütfen tekrar deneyin."
    }


@pytest.mark.asyncio
async def test_assistant_feature_flag_fails_closed(
    assistant_context,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client, _ = assistant_context
    monkeypatch.setattr(settings, "assistant_enabled", False)

    response = await client.post(
        "/api/v1/assistant/query",
        json={
            "question": "Bu ay ne harcadım?",
            "timezone": "Europe/Istanbul",
        },
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "Finans asistanı şu anda kullanılamıyor."}
