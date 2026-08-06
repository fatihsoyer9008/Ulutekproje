import json
import uuid
from datetime import UTC, datetime, time
from typing import Protocol
from zoneinfo import ZoneInfo

from google import genai
from google.genai import types
from sqlalchemy.ext.asyncio import AsyncSession

from app.assistant_schemas import (
    AssistantAnswerPayload,
    AssistantFinancialSummary,
    AssistantPeriodPlan,
    AssistantQueryRequest,
    AssistantQueryResponse,
)
from app.constants.ai_prompts import (
    ASSISTANT_ANSWER_SYSTEM_INSTRUCTION,
    ASSISTANT_PERIOD_SYSTEM_INSTRUCTION,
)
from app.repositories.cloud_transactions import CloudTransactionRepository

_PERIOD_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "start_date": {"type": "string"},
        "end_date_exclusive": {"type": "string"},
    },
    "required": ["start_date", "end_date_exclusive"],
}

_ANSWER_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "answer": {"type": "string"},
    },
    "required": ["answer"],
}


class AssistantProviderError(RuntimeError):
    pass


class InvalidAssistantPeriod(ValueError):
    pass


class AssistantModelService(Protocol):
    model_name: str

    async def plan_period(
        self,
        *,
        question: str,
        timezone_name: str,
        current_local_datetime: datetime,
    ) -> AssistantPeriodPlan:
        pass

    async def generate_answer(
        self,
        *,
        question: str,
        summary: AssistantFinancialSummary,
    ) -> AssistantAnswerPayload:
        pass


class GeminiAssistantModelService:
    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        timeout_ms: int,
    ) -> None:
        self._api_key = api_key
        self.model_name = model
        self._timeout_ms = timeout_ms

    async def plan_period(
        self,
        *,
        question: str,
        timezone_name: str,
        current_local_datetime: datetime,
    ) -> AssistantPeriodPlan:
        client = genai.Client(
            api_key=self._api_key,
            http_options=types.HttpOptions(
                timeout=self._timeout_ms,
            ),
        )
        async_client = client.aio
        contents = json.dumps(
            {
                "current_local_datetime": current_local_datetime.isoformat(),
                "timezone": timezone_name,
                "question": question,
            },
            ensure_ascii=False,
        )

        try:
            response = await async_client.models.generate_content(
                model=self.model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=ASSISTANT_PERIOD_SYSTEM_INSTRUCTION,
                    response_mime_type="application/json",
                    response_schema=_PERIOD_RESPONSE_SCHEMA,
                    max_output_tokens=128,
                ),
            )
            if response.parsed is not None:
                return AssistantPeriodPlan.model_validate(response.parsed)
            if response.text:
                return AssistantPeriodPlan.model_validate_json(response.text)
            raise AssistantProviderError(
                "Assistant period planner returned an empty response"
            )
        except AssistantProviderError:
            raise
        except Exception as exc:
            raise AssistantProviderError("Assistant period planner failed") from exc
        finally:
            await async_client.aclose()

    async def generate_answer(
        self,
        *,
        question: str,
        summary: AssistantFinancialSummary,
    ) -> AssistantAnswerPayload:
        client = genai.Client(
            api_key=self._api_key,
            http_options=types.HttpOptions(
                timeout=self._timeout_ms,
            ),
        )
        async_client = client.aio
        contents = json.dumps(
            {
                "question": question,
                "financial_context": _grounded_context(summary),
            },
            ensure_ascii=False,
        )

        try:
            response = await async_client.models.generate_content(
                model=self.model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=ASSISTANT_ANSWER_SYSTEM_INSTRUCTION,
                    response_mime_type="application/json",
                    response_schema=_ANSWER_RESPONSE_SCHEMA,
                    max_output_tokens=500,
                ),
            )
            if response.parsed is not None:
                return AssistantAnswerPayload.model_validate(response.parsed)
            if response.text:
                return AssistantAnswerPayload.model_validate_json(response.text)
            raise AssistantProviderError(
                "Assistant answer generator returned an empty response"
            )
        except AssistantProviderError:
            raise
        except Exception as exc:
            raise AssistantProviderError("Assistant answer generator failed") from exc
        finally:
            await async_client.aclose()


class AssistantQueryService:
    def __init__(
        self,
        db: AsyncSession,
        *,
        max_period_days: int,
    ) -> None:
        self.db = db
        self.transactions = CloudTransactionRepository(db)
        self.max_period_days = max_period_days

    async def query(
        self,
        *,
        user_id: uuid.UUID,
        payload: AssistantQueryRequest,
        model: AssistantModelService,
        now_utc: datetime | None = None,
    ) -> AssistantQueryResponse:
        client_timezone = ZoneInfo(payload.timezone_name)
        current_utc = now_utc or datetime.now(UTC)
        if current_utc.tzinfo is None:
            current_utc = current_utc.replace(tzinfo=UTC)
        current_local = current_utc.astimezone(client_timezone)

        plan = await model.plan_period(
            question=payload.question,
            timezone_name=payload.timezone_name,
            current_local_datetime=current_local,
        )

        period_days = (plan.end_date_exclusive - plan.start_date).days
        if period_days < 1 or period_days > self.max_period_days:
            raise InvalidAssistantPeriod("Assistant period is outside allowed limits")

        period_start_utc = datetime.combine(
            plan.start_date,
            time.min,
            tzinfo=client_timezone,
        ).astimezone(UTC)
        period_end_utc = datetime.combine(
            plan.end_date_exclusive,
            time.min,
            tzinfo=client_timezone,
        ).astimezone(UTC)

        summary = await self.transactions.summarize_for_assistant(
            user_id=user_id,
            period_start_utc=period_start_utc,
            period_end_utc=period_end_utc,
        )
        await self.db.rollback()

        if summary.transaction_count == 0:
            answer = (
                "Seçilen tarih aralığında senkronize edilmiş bir işlem "
                "bulamadım. Senkronizasyonun tamamlandığını kontrol edip "
                "farklı bir tarih aralığı sorabilirsin."
            )
        else:
            generated = await model.generate_answer(
                question=payload.question,
                summary=summary,
            )
            answer = generated.answer

        return AssistantQueryResponse(
            answer=answer,
            period_start=plan.start_date,
            period_end_exclusive=plan.end_date_exclusive,
            data_as_of=_as_utc(summary.data_as_of),
        )


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _format_try(amount_in_minor: int) -> str:
    sign = "-" if amount_in_minor < 0 else ""
    absolute = abs(amount_in_minor)
    whole, fraction = divmod(absolute, 100)
    whole_text = f"{whole:,}".replace(",", ".")
    return f"{sign}{whole_text},{fraction:02d} TL"


def _grounded_context(
    summary: AssistantFinancialSummary,
) -> dict[str, object]:
    return {
        "trusted_currency": "TRY",
        "trusted_period_start_utc": summary.period_start_utc.isoformat(),
        "trusted_period_end_utc": summary.period_end_utc.isoformat(),
        "trusted_data_as_of": (
            _as_utc(summary.data_as_of).isoformat()
            if summary.data_as_of is not None
            else None
        ),
        "trusted_transaction_count": summary.transaction_count,
        "trusted_expense_total": _format_try(summary.expense_total_in_minor),
        "trusted_income_total": _format_try(summary.income_total_in_minor),
        "trusted_net_total": _format_try(
            summary.income_total_in_minor - summary.expense_total_in_minor
        ),
        "expense_categories": [
            {
                "untrusted_category_label": item.category,
                "trusted_total": _format_try(item.total_in_minor),
                "trusted_transaction_count": item.transaction_count,
            }
            for item in summary.categories
        ],
        "expense_merchants": [
            {
                "untrusted_merchant_label": item.merchant_name,
                "trusted_total": _format_try(item.total_in_minor),
                "trusted_transaction_count": item.transaction_count,
            }
            for item in summary.merchants
        ],
        "largest_expenses": [
            {
                "trusted_amount": _format_try(item.amount_in_minor),
                "untrusted_category_label": item.category,
                "untrusted_merchant_label": item.merchant_name,
                "trusted_transaction_date": (item.transaction_date.isoformat()),
            }
            for item in summary.largest_expenses
        ],
    }
