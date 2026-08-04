import logging
from time import perf_counter
from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    File,
    Header,
    HTTPException,
    Request,
    UploadFile,
    status,
)

from app.api.dependencies import get_rate_limiter, request_ip
from app.core.config import settings
from app.core.rate_limit import RateLimiter
from app.core.receipt_image_security import read_validated_receipt_image
from app.core.receipt_rate_limits import enforce_receipt_rate_limits
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.receipt_parser import (
    DummyReceiptParserService,
    GeminiReceiptParserService,
    ReceiptParserError,
    ReceiptParserService,
)

router = APIRouter(prefix="/api/v1", tags=["receipts"])
logger = logging.getLogger("app.receipts")

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
    await enforce_receipt_rate_limits(
        client_ip=request_ip(request),
        installation_id=installation_id,
        limiter=limiter,
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

    started_at = perf_counter()
    request_id = getattr(request.state, "request_id", "unknown")
    model_name = str(getattr(parser, "model_name", "unknown"))
    outcome = "success"
    try:
        return await parser.parse(payload)
    except ReceiptParserError as exc:
        outcome = "provider_error"
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=("Fiş metni yapay zekâ servisi tarafından ayrıştırılamadı"),
        ) from exc
    except Exception:
        outcome = "unexpected_error"
        raise
    finally:
        duration_ms = (perf_counter() - started_at) * 1000
        logger.info(
            "receipt_parse_completed request_id=%s duration_ms=%.2f "
            "model=%s outcome=%s",
            request_id,
            duration_ms,
            model_name,
            outcome,
        )


@router.post(
    "/receipts/parse-image",
    response_model=ReceiptParserResponse,
)
async def parse_receipt_image(
    request: Request,
    image: Annotated[
        UploadFile,
        File(description="JPEG veya PNG biçimindeki fiş fotoğrafı"),
    ],
    installation_id: InstallationIdHeader = None,
    parser: ReceiptParserService = Depends(get_receipt_parser_service),
) -> ReceiptParserResponse:
    del installation_id
    validated_image = await read_validated_receipt_image(image)
    started_at = perf_counter()
    request_id = getattr(request.state, "request_id", "unknown")
    model_name = str(getattr(parser, "model_name", "unknown"))
    outcome = "success"

    try:
        return await parser.parse_image(
            image_bytes=validated_image.data,
            mime_type=validated_image.mime_type,
        )
    except ReceiptParserError as exc:
        outcome = "provider_error"
        provider_error = exc.__cause__ or exc
        logger.warning(
            "receipt_image_provider_failed request_id=%s model=%s " "error_type=%s",
            request_id,
            model_name,
            type(provider_error).__name__,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=("Fiş görüntüsü yapay zekâ servisi tarafından ayrıştırılamadı"),
        ) from exc
    except Exception:
        outcome = "unexpected_error"
        raise
    finally:
        duration_ms = (perf_counter() - started_at) * 1000
        logger.info(
            "receipt_image_parse_completed request_id=%s duration_ms=%.2f "
            "model=%s outcome=%s",
            request_id,
            duration_ms,
            model_name,
            outcome,
        )
