import logging
import uuid
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
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_rate_limiter, request_ip
from app.cloud_receipt_schemas import ApproveReceiptRequest, PendingReceiptOut
from app.core.config import settings
from app.core.database import get_db_session
from app.core.rate_limit import RateLimiter
from app.core.receipt_image_security import read_validated_receipt_image
from app.core.receipt_rate_limits import enforce_receipt_rate_limits
from app.models.user import User
from app.schemas import ReceiptParserRequest, ReceiptParserResponse
from app.services.cloud_receipt_service import CloudReceiptService
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
            "receipt_image_provider_failed request_id=%s model=%s error_type=%s",
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


def _receipt_not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Onay bekleyen fiş bulunamadı.",
    )


@router.get("/receipts/pending", response_model=list[PendingReceiptOut])
async def list_pending_receipts(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[PendingReceiptOut]:
    receipts = await CloudReceiptService(db).list_pending(user_id=user.id)
    return [PendingReceiptOut.model_validate(r, from_attributes=True) for r in receipts]


@router.post("/receipts/{receipt_id}/approve", response_model=PendingReceiptOut)
async def approve_pending_receipt(
    receipt_id: uuid.UUID,
    payload: ApproveReceiptRequest | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PendingReceiptOut:
    receipt = await CloudReceiptService(db).approve(
        user_id=user.id,
        receipt_id=receipt_id,
        overrides=payload or ApproveReceiptRequest(),
    )
    if receipt is None:
        raise _receipt_not_found()
    return PendingReceiptOut.model_validate(receipt, from_attributes=True)


@router.post("/receipts/{receipt_id}/reject", response_model=PendingReceiptOut)
async def reject_pending_receipt(
    receipt_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PendingReceiptOut:
    receipt = await CloudReceiptService(db).reject(
        user_id=user.id, receipt_id=receipt_id
    )
    if receipt is None:
        raise _receipt_not_found()
    return PendingReceiptOut.model_validate(receipt, from_attributes=True)
