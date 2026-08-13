import asyncio
import logging
import uuid

from redis.asyncio import Redis
from redis.exceptions import RedisError

logger = logging.getLogger(__name__)


class DebtSummaryCacheUnavailable(RuntimeError):
    pass


class DebtSummaryCache:
    def __init__(
        self,
        redis: Redis,
        *,
        max_attempts: int = 3,
        initial_delay_seconds: float = 0.05,
    ) -> None:
        if max_attempts < 1:
            raise ValueError("max_attempts must be at least 1")
        if initial_delay_seconds < 0:
            raise ValueError("initial_delay_seconds cannot be negative")

        self.redis = redis
        self.max_attempts = max_attempts
        self.initial_delay_seconds = initial_delay_seconds

    @staticmethod
    def key(group_id: uuid.UUID) -> str:
        return f"group-debt-summary:v1:{group_id}"

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
                    "debt_summary_cache_invalidation_retry " "group_id=%s attempt=%s",
                    group_id,
                    attempt,
                )
                delay = self.initial_delay_seconds * (2 ** (attempt - 1))
                await asyncio.sleep(delay)
