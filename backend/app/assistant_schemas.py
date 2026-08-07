from datetime import date, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator

ASSISTANT_DISCLAIMER = "Bu bir yatırım tavsiyesi değildir."


class AssistantQueryRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        populate_by_name=True,
    )

    question: str = Field(min_length=1, max_length=500)
    timezone_name: str = Field(
        default="Europe/Istanbul",
        alias="timezone",
        min_length=1,
        max_length=64,
    )

    @field_validator("question")
    @classmethod
    def normalize_question(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("question cannot be blank")
        return normalized

    @field_validator("timezone_name")
    @classmethod
    def validate_timezone(cls, value: str) -> str:
        normalized = value.strip()
        try:
            ZoneInfo(normalized)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("timezone must be a valid IANA timezone") from exc
        return normalized


class AssistantConsentUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    accepted: bool
    consent_version: str = Field(min_length=1, max_length=64)


class AssistantStatusResponse(BaseModel):
    enabled: bool
    required_consent_version: str
    consent_granted: bool
    consent_granted_at: datetime | None
    consent_revoked_at: datetime | None


class AssistantPeriodPlan(BaseModel):
    model_config = ConfigDict(extra="forbid")

    start_date: date
    end_date_exclusive: date


class AssistantAnswerPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    answer: str = Field(min_length=1, max_length=2000)

    @field_validator("answer")
    @classmethod
    def normalize_answer(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("answer cannot be blank")
        return normalized


class AssistantCategorySummary(BaseModel):
    category: str
    total_in_minor: int
    transaction_count: int


class AssistantMerchantSummary(BaseModel):
    merchant_name: str
    total_in_minor: int
    transaction_count: int


class AssistantLargestExpense(BaseModel):
    amount_in_minor: int
    category: str
    merchant_name: str | None
    transaction_date: datetime


class AssistantFinancialSummary(BaseModel):
    period_start_utc: datetime
    period_end_utc: datetime
    expense_total_in_minor: int
    income_total_in_minor: int
    transaction_count: int
    data_as_of: datetime | None
    categories: list[AssistantCategorySummary]
    merchants: list[AssistantMerchantSummary]
    largest_expenses: list[AssistantLargestExpense]


class AssistantQueryResponse(BaseModel):
    answer: str
    period_start: date
    period_end_exclusive: date
    data_as_of: datetime | None
    currency: str = "TRY"
    disclaimer: str = ASSISTANT_DISCLAIMER
