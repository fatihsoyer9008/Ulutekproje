import logging
import uuid
from decimal import Decimal
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
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_current_user, get_rate_limiter, request_ip
from app.core.config import settings
from app.core.database import get_db_session
from app.core.rate_limit import RateLimiter
from app.core.receipt_image_security import read_validated_receipt_image
from app.core.receipt_rate_limits import enforce_receipt_rate_limits
from app.core.security import privacy_hash
from app.models.cloud_receipt import CloudReceipt, CloudReceiptLineItem
from app.models.user import User
from app.receipt_sync_schemas import (
    ReceiptLineItemSyncResponse,
    ReceiptSyncRequest,
    ReceiptSyncResponse,
)
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


@router.post("/receipts/sync", response_model=ReceiptSyncResponse)
async def sync_receipt(
    payload: ReceiptSyncRequest,
    installation_id: Annotated[
        str,
        Header(
            alias="X-Installation-ID",
            min_length=16,
            max_length=128,
            pattern=r"^[A-Za-z0-9._:-]+$",
        ),
    ],
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ReceiptSyncResponse:
    receipt = await db.scalar(
        select(CloudReceipt)
        .where(
            CloudReceipt.user_id == user.id,
            CloudReceipt.client_record_id == payload.client_record_id,
            CloudReceipt.deleted_at.is_(None),
        )
        .options(
            selectinload(CloudReceipt.line_items),
            selectinload(CloudReceipt.group_expenses),
        )
    )
    if receipt is None:
        receipt = CloudReceipt(
            user_id=user.id,
            client_record_id=payload.client_record_id,
            installation_id_hash=privacy_hash(f"installation:{installation_id}"),
            client_created_at=payload.client_created_at,
            client_updated_at=payload.client_updated_at,
        )
        db.add(receipt)
    elif receipt.group_expenses:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "receipt_already_used",
                "message": "Bu fiş daha önce bir grup harcamasında kullanılmış.",
            },
        )

    receipt.installation_id_hash = privacy_hash(f"installation:{installation_id}")
    receipt.merchant_name = payload.merchant_name
    receipt.total_amount_in_minor = payload.total_amount_in_minor
    receipt.currency = payload.currency
    receipt.receipt_date = payload.receipt_date
    receipt.category = payload.category
    receipt.raw_ocr_text = payload.raw_ocr_text
    receipt.normalized_ocr_text = payload.raw_ocr_text
    receipt.is_parse_successful = True
    receipt.client_updated_at = payload.client_updated_at
    existing_items = {item.position: item for item in receipt.line_items}
    retained_positions: set[int] = set()
    for item in sorted(payload.line_items, key=lambda value: value.position):
        retained_positions.add(item.position)
        line_item = existing_items.get(item.position)
        if line_item is None:
            line_item = CloudReceiptLineItem(
                client_record_id=uuid.uuid5(
                    payload.client_record_id, f"line-item:{item.position}"
                ),
                position=item.position,
            )
            receipt.line_items.append(line_item)
        line_item.name = item.name.strip()
        line_item.price_in_minor = item.total_amount_in_minor
        line_item.quantity = (
            Decimal(item.quantity_milli) / 1000
            if item.quantity_milli is not None
            else None
        )
        line_item.unit_price_in_minor = item.unit_price_in_minor
        line_item.category = item.category
    for position, line_item in existing_items.items():
        if position not in retained_positions:
            await db.delete(line_item)
    await db.flush()
    response = ReceiptSyncResponse(
        receipt_id=receipt.id,
        total_amount_in_minor=receipt.total_amount_in_minor or 0,
        line_items=[
            ReceiptLineItemSyncResponse(
                receipt_line_item_id=item.id,
                position=item.position,
                name=item.name,
                total_amount_in_minor=item.price_in_minor,
                quantity_milli=(
                    int(item.quantity * 1000) if item.quantity is not None else None
                ),
                unit_price_in_minor=item.unit_price_in_minor,
            )
            for item in sorted(receipt.line_items, key=lambda value: value.position)
        ],
    )
    await db.commit()
    return response
