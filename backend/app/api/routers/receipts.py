from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status

from app.api.dependencies import get_rate_limiter, request_ip
from app.core.config import settings
from app.core.rate_limit import RateLimiter, RateLimitRule
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import (
    DummyReceiptParserService,
    GeminiReceiptParserService,
    ReceiptParserError,
    ReceiptParserService,
)

router = APIRouter(prefix="/api/v1", tags=["receipts"])

RECEIPT_IP_BURST = RateLimitRule(
    name="receipt-ip-burst",
    limit=settings.receipt_ip_burst_limit,
    window_seconds=60,
)
RECEIPT_IP_DAILY = RateLimitRule(
    name="receipt-ip-daily",
    limit=settings.receipt_ip_daily_limit,
    window_seconds=86_400,
)
RECEIPT_INSTALLATION_BURST = RateLimitRule(
    name="receipt-installation-burst",
    limit=settings.receipt_installation_burst_limit,
    window_seconds=60,
)
RECEIPT_INSTALLATION_DAILY = RateLimitRule(
    name="receipt-installation-daily",
    limit=settings.receipt_installation_daily_limit,
    window_seconds=86_400,
)

InstallationIdHeader = Annotated[
    str | None,
    Header(
        alias="X-Installation-ID",
        min_length=16,
        max_length=128,
        pattern=r"^[A-Za-z0-9._:-]+$",
    ),
]


def get_receipt_parser_service() -> ReceiptParserService:
    if settings.use_dummy_parser:
        return DummyReceiptParserService()

    if settings.gemini_api_key is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GEMINI_API_KEY yapılandırılmamış",
        )

    return GeminiReceiptParserService(
        api_key=settings.gemini_api_key.get_secret_value(),
        model=settings.gemini_model,
    )


async def _enforce_receipt_limits(
    *,
    request: Request,
    installation_id: str | None,
    limiter: RateLimiter,
) -> None:
    ip_identifier = f"ip:{request_ip(request)}"

    await limiter.enforce(
        RECEIPT_IP_BURST,
        identifier=ip_identifier,
    )
    await limiter.enforce(
        RECEIPT_IP_DAILY,
        identifier=ip_identifier,
    )

    if installation_id is None:
        return

    installation_identifier = f"installation:{installation_id}"

    await limiter.enforce(
        RECEIPT_INSTALLATION_BURST,
        identifier=installation_identifier,
    )
    await limiter.enforce(
        RECEIPT_INSTALLATION_DAILY,
        identifier=installation_identifier,
    )


@router.post("/parse-receipt", response_model=ReceiptParserResponse)
async def parse_receipt(
    payload: ReceiptParserRequest,
    request: Request,
    installation_id: InstallationIdHeader = None,
    limiter: RateLimiter = Depends(get_rate_limiter),
    parser: ReceiptParserService = Depends(get_receipt_parser_service),
) -> ReceiptParserResponse:
    await _enforce_receipt_limits(
        request=request,
        installation_id=installation_id,
        limiter=limiter,
    )

    try:
        return await parser.parse(payload)
    except ReceiptParserError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=("Fiş metni yapay zekâ servisi tarafından " "ayrıştırılamadı"),
        ) from exc
