import hashlib
import json
import uuid
from typing import NoReturn

from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Response,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_debt_summary_cache,
    require_group_member,
)
from app.core.database import get_db_session
from app.core.security import privacy_hash
from app.models.group import GroupMember
from app.models.settlement import SettlementIdempotencyRecord
from app.repositories.settlements import SettlementRepository
from app.services.debt_summary_cache import (
    DebtSummaryCache,
    DebtSummaryCacheUnavailable,
)
from app.services.debt_summary_service import (
    DebtSummaryNotFoundError,
    DebtSummaryService,
)
from app.services.settlement_service import (
    SettlementService,
    SettlementValidationError,
)
from app.settlement_schemas import (
    DebtSummaryResponse,
    SettlementCreateRequest,
    SettlementEnvelope,
    SettlementResponse,
    SettlementsResponse,
)

router = APIRouter(prefix="/api/v1/groups", tags=["groups"])

_ERRORS = {
    "group_not_found": (
        status.HTTP_404_NOT_FOUND,
        "group_not_found",
        "Grup bulunamadı.",
    ),
    "group_forbidden": (
        status.HTTP_403_FORBIDDEN,
        "group_forbidden",
        "Bu grup için yetkiniz yok.",
    ),
    "sender_must_match_actor": (
        status.HTTP_403_FORBIDDEN,
        "group_forbidden",
        "Ödemeyi gönderen kullanıcı oturum sahibi olmalıdır.",
    ),
    "member_not_found": (
        status.HTTP_404_NOT_FOUND,
        "member_not_found",
        "Gönderen ve alan aktif grup üyesi olmalıdır.",
    ),
    "self_settlement": (
        status.HTTP_400_BAD_REQUEST,
        "invalid_request",
        "Kullanıcı kendisine ödeme yapamaz.",
    ),
    "invalid_amount": (
        status.HTTP_400_BAD_REQUEST,
        "invalid_request",
        "Ödeme tutarı pozitif bir minor-unit tamsayısı olmalıdır.",
    ),
    "invalid_settled_at": (
        status.HTTP_400_BAD_REQUEST,
        "invalid_request",
        "Ödeme zamanı saat dilimi içermelidir.",
    ),
    "currency_mismatch": (
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        "currency_mismatch",
        "Ödeme para birimi grup para birimiyle eşleşmelidir.",
    ),
}


def _request_hash(payload: SettlementCreateRequest) -> str:
    canonical = json.dumps(
        payload.model_dump(mode="json"),
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def _raise_idempotency_conflict() -> NoReturn:
    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={
            "code": "idempotency_conflict",
            "message": "Ödeme isteği daha önce farklı bilgilerle gönderildi.",
        },
    ) from None


def _raise_validation_error(
    error: SettlementValidationError,
) -> NoReturn:
    status_code, public_code, message = _ERRORS[error.code]
    raise HTTPException(
        status_code=status_code,
        detail={
            "code": public_code,
            "message": message,
        },
    ) from None


async def _invalidate_debt_cache(
    debt_cache: DebtSummaryCache,
    group_id: uuid.UUID,
) -> None:
    try:
        await debt_cache.invalidate(group_id)
    except DebtSummaryCacheUnavailable:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "cache_invalidation_pending",
                "message": (
                    "Ödeme kaydedildi ancak borç özeti henüz "
                    "yenilenemedi. Aynı Idempotency-Key ile tekrar deneyin."
                ),
            },
            headers={"Retry-After": "1"},
        ) from None


async def _replay_response(
    record: SettlementIdempotencyRecord,
    *,
    group_id: uuid.UUID,
    request_hash: str,
    response: Response,
    repository: SettlementRepository,
    debt_cache: DebtSummaryCache,
) -> SettlementEnvelope:
    if record.request_hash != request_hash:
        _raise_idempotency_conflict()

    if record.settlement_id is None:
        raise RuntimeError("Settlement idempotency result is unavailable")

    settlement = await repository.get_by_id(record.settlement_id)
    if settlement is None or settlement.group_id != group_id:
        raise RuntimeError("Settlement idempotency resource is unavailable")

    await _invalidate_debt_cache(debt_cache, group_id)

    response.status_code = status.HTTP_200_OK
    response.headers["Idempotency-Replayed"] = "true"
    return SettlementEnvelope(settlement=SettlementResponse.from_model(settlement))


@router.post(
    "/{group_id}/settlements",
    response_model=SettlementEnvelope,
    status_code=status.HTTP_201_CREATED,
)
async def create_settlement(
    group_id: uuid.UUID,
    payload: SettlementCreateRequest,
    response: Response,
    actor_membership: GroupMember = Depends(require_group_member),
    idempotency_key: str = Header(
        alias="Idempotency-Key",
        min_length=8,
        max_length=128,
    ),
    db: AsyncSession = Depends(get_db_session),
    debt_cache: DebtSummaryCache = Depends(get_debt_summary_cache),
) -> SettlementEnvelope:
    actor_user_id = actor_membership.user_id
    request_hash = _request_hash(payload)
    idempotency_key_hash = privacy_hash(
        f"settlement-create:{group_id}:{actor_user_id}:{idempotency_key}"
    )

    repository = SettlementRepository(db)
    existing = await repository.get_idempotency(
        group_id=group_id,
        actor_user_id=actor_user_id,
        idempotency_key_hash=idempotency_key_hash,
    )
    if existing is not None:
        return await _replay_response(
            existing,
            group_id=group_id,
            request_hash=request_hash,
            response=response,
            repository=repository,
            debt_cache=debt_cache,
        )

    reservation = await repository.try_reserve_idempotency(
        group_id=group_id,
        actor_user_id=actor_user_id,
        idempotency_key_hash=idempotency_key_hash,
        request_hash=request_hash,
    )
    if reservation is None:
        concurrent = await repository.get_idempotency(
            group_id=group_id,
            actor_user_id=actor_user_id,
            idempotency_key_hash=idempotency_key_hash,
        )
        if concurrent is None:
            raise RuntimeError("Settlement idempotency record disappeared")
        return await _replay_response(
            concurrent,
            group_id=group_id,
            request_hash=request_hash,
            response=response,
            repository=repository,
            debt_cache=debt_cache,
        )

    try:
        settlement = await SettlementService(db).create(
            group_id=group_id,
            actor_user_id=actor_user_id,
            from_user_id=payload.from_user_id,
            to_user_id=payload.to_user_id,
            amount_in_minor=payload.amount_in_minor,
            currency=payload.currency,
            settled_at=payload.settled_at,
            note=payload.note,
        )
    except SettlementValidationError as error:
        _raise_validation_error(error)

    reservation.settlement_id = settlement.id
    await db.commit()

    await _invalidate_debt_cache(debt_cache, group_id)

    return SettlementEnvelope(settlement=SettlementResponse.from_model(settlement))


@router.get(
    "/{group_id}/settlements",
    response_model=SettlementsResponse,
)
async def list_settlements(
    group_id: uuid.UUID,
    actor_membership: GroupMember = Depends(require_group_member),
    db: AsyncSession = Depends(get_db_session),
) -> SettlementsResponse:
    del actor_membership
    settlements = await SettlementRepository(db).list_for_group(group_id)
    return SettlementsResponse(
        settlements=[
            SettlementResponse.from_model(settlement) for settlement in settlements
        ]
    )


@router.get(
    "/{group_id}/debts",
    response_model=DebtSummaryResponse,
    include_in_schema=False,
)
@router.get(
    "/{group_id}/debt-summary",
    response_model=DebtSummaryResponse,
)
async def get_debt_summary(
    group_id: uuid.UUID,
    actor_membership: GroupMember = Depends(require_group_member),
    db: AsyncSession = Depends(get_db_session),
    debt_cache: DebtSummaryCache = Depends(get_debt_summary_cache),
) -> DebtSummaryResponse:
    del actor_membership

    cached_summary = await debt_cache.get(group_id)
    if cached_summary is not None:
        return DebtSummaryResponse.from_domain(cached_summary)

    try:
        summary = await DebtSummaryService(db).get_for_group(group_id)
    except DebtSummaryNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": "group_not_found",
                "message": "Grup bulunamadı.",
            },
        ) from None

    await debt_cache.set(summary)
    return DebtSummaryResponse.from_domain(summary)
