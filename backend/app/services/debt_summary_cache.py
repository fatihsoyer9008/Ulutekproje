import asyncio
import json
import logging
import uuid
from datetime import datetime

from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.domain.debts import DebtBalance, DebtSummary, DebtTransfer

logger = logging.getLogger(__name__)


class DebtSummaryCacheUnavailable(RuntimeError):
    pass


class DebtSummaryCache:
    def __init__(
        self,
        redis: Redis,
        *,
        ttl_seconds: int = 300,
        max_attempts: int = 3,
        initial_delay_seconds: float = 0.05,
    ) -> None:
        if ttl_seconds < 1:
            raise ValueError("ttl_seconds must be at least 1")
        if max_attempts < 1:
            raise ValueError("max_attempts must be at least 1")
        if initial_delay_seconds < 0:
            raise ValueError("initial_delay_seconds cannot be negative")

        self.redis = redis
        self.ttl_seconds = ttl_seconds
        self.max_attempts = max_attempts
        self.initial_delay_seconds = initial_delay_seconds

    @staticmethod
    def key(group_id: uuid.UUID) -> str:
        return f"group-debt-summary:v1:{group_id}"

    async def get(self, group_id: uuid.UUID) -> DebtSummary | None:
        try:
            cached = await self.redis.get(self.key(group_id))
        except RedisError:
            logger.warning(
                "debt_summary_cache_read_failed group_id=%s",
                group_id,
                exc_info=True,
            )
            return None

        if cached is None:
            logger.info("debt_summary_cache_miss group_id=%s", group_id)
            return None

        try:
            summary = self._deserialize(cached)
        except (json.JSONDecodeError, KeyError, TypeError, ValueError):
            logger.warning(
                "debt_summary_cache_payload_invalid group_id=%s",
                group_id,
                exc_info=True,
            )
            return None

        logger.info("debt_summary_cache_hit group_id=%s", group_id)
        return summary

    async def set(self, summary: DebtSummary) -> bool:
        group_id = uuid.UUID(summary.group_id)
        try:
            await self.redis.set(
                self.key(group_id),
                self._serialize(summary),
                ex=self.ttl_seconds,
            )
        except RedisError:
            logger.warning(
                "debt_summary_cache_write_failed group_id=%s",
                group_id,
                exc_info=True,
            )
            return False
        return True

    async def invalidate_best_effort(self, group_id: uuid.UUID) -> bool:
        try:
            await self.invalidate(group_id)
        except DebtSummaryCacheUnavailable:
            return False
        return True

    async def invalidate(self, group_id: uuid.UUID) -> None:
        for attempt in range(1, self.max_attempts + 1):
            try:
                await self.redis.delete(self.key(group_id))
                return
            except RedisError as error:
                if attempt == self.max_attempts:
                    logger.error(
                        "debt_summary_cache_invalidation_failed "
                        "group_id=%s attempts=%s",
                        group_id,
                        attempt,
                        exc_info=True,
                    )
                    raise DebtSummaryCacheUnavailable(
                        "Debt summary cache could not be invalidated"
                    ) from error

                logger.warning(
                    "debt_summary_cache_invalidation_retry group_id=%s attempt=%s",
                    group_id,
                    attempt,
                )
                delay = self.initial_delay_seconds * (2 ** (attempt - 1))
                await asyncio.sleep(delay)

    @staticmethod
    def _serialize(summary: DebtSummary) -> str:
        return json.dumps(
            {
                "group_id": summary.group_id,
                "currency": summary.currency,
                "balances": [
                    {
                        "user_id": balance.user_id,
                        "display_name": balance.display_name,
                        "net_amount_in_minor": balance.net_amount_in_minor,
                    }
                    for balance in summary.balances
                ],
                "suggested_transfers": [
                    {
                        "from_user_id": transfer.from_user_id,
                        "to_user_id": transfer.to_user_id,
                        "amount_in_minor": transfer.amount_in_minor,
                    }
                    for transfer in summary.suggested_transfers
                ],
                "generated_at": summary.generated_at.isoformat(),
            },
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )

    @staticmethod
    def _deserialize(payload: str | bytes) -> DebtSummary:
        value = json.loads(payload)
        generated_at = datetime.fromisoformat(value["generated_at"])
        if generated_at.tzinfo is None:
            raise ValueError("cached generated_at must include a timezone")
        return DebtSummary(
            group_id=value["group_id"],
            currency=value["currency"],
            balances=tuple(
                DebtBalance(
                    user_id=balance["user_id"],
                    display_name=balance["display_name"],
                    net_amount_in_minor=balance["net_amount_in_minor"],
                )
                for balance in value["balances"]
            ),
            suggested_transfers=tuple(
                DebtTransfer(
                    from_user_id=transfer["from_user_id"],
                    to_user_id=transfer["to_user_id"],
                    amount_in_minor=transfer["amount_in_minor"],
                )
                for transfer in value["suggested_transfers"]
            ),
            generated_at=generated_at,
        )
