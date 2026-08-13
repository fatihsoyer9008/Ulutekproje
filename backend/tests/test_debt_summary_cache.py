import uuid

import pytest
from redis.exceptions import RedisError

from app.services.debt_summary_cache import (
    DebtSummaryCache,
    DebtSummaryCacheUnavailable,
)


class FlakyRedis:
    def __init__(self, failures_remaining: int) -> None:
        self.failures_remaining = failures_remaining
        self.deleted_keys: list[str] = []

    async def delete(self, key: str) -> int:
        if self.failures_remaining > 0:
            self.failures_remaining -= 1
            raise RedisError("temporary test failure")

        self.deleted_keys.append(key)
        return 1


@pytest.mark.asyncio
async def test_invalidation_retries_and_recovers() -> None:
    group_id = uuid.uuid4()
    redis = FlakyRedis(failures_remaining=2)
    cache = DebtSummaryCache(
        redis,
        max_attempts=3,
        initial_delay_seconds=0,
    )

    await cache.invalidate(group_id)

    assert redis.deleted_keys == [DebtSummaryCache.key(group_id)]


@pytest.mark.asyncio
async def test_invalidation_reports_exhausted_retries() -> None:
    redis = FlakyRedis(failures_remaining=3)
    cache = DebtSummaryCache(
        redis,
        max_attempts=3,
        initial_delay_seconds=0,
    )

    with pytest.raises(DebtSummaryCacheUnavailable):
        await cache.invalidate(uuid.uuid4())
