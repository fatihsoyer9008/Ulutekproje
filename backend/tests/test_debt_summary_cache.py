import logging
import uuid
from datetime import UTC, datetime

import pytest
from redis.exceptions import RedisError

from app.domain.debts import DebtBalance, DebtSummary, DebtTransfer
from app.services.debt_summary_cache import (
    DebtSummaryCache,
    DebtSummaryCacheUnavailable,
)


class MemoryRedis:
    def __init__(self) -> None:
        self.values: dict[str, str] = {}
        self.set_calls: list[tuple[str, int]] = []

    async def get(self, key: str) -> str | None:
        return self.values.get(key)

    async def set(self, key: str, value: str, *, ex: int) -> bool:
        self.values[key] = value
        self.set_calls.append((key, ex))
        return True

    async def delete(self, key: str) -> int:
        return int(self.values.pop(key, None) is not None)


class UnavailableRedis:
    async def get(self, key: str) -> str | None:
        del key
        raise RedisError("redis unavailable")

    async def set(self, key: str, value: str, *, ex: int) -> bool:
        del key, value, ex
        raise RedisError("redis unavailable")

    async def delete(self, key: str) -> int:
        del key
        raise RedisError("redis unavailable")


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


def _summary(group_id: uuid.UUID) -> DebtSummary:
    debtor_id = uuid.uuid4()
    creditor_id = uuid.uuid4()
    return DebtSummary(
        group_id=str(group_id),
        currency="TRY",
        balances=(
            DebtBalance(
                user_id=str(debtor_id),
                display_name="Borclu",
                net_amount_in_minor=-2500,
            ),
            DebtBalance(
                user_id=str(creditor_id),
                display_name="Alacakli",
                net_amount_in_minor=2500,
            ),
        ),
        suggested_transfers=(
            DebtTransfer(
                from_user_id=str(debtor_id),
                to_user_id=str(creditor_id),
                amount_in_minor=2500,
            ),
        ),
        generated_at=datetime(2026, 8, 14, 8, 0, tzinfo=UTC),
    )


@pytest.mark.asyncio
async def test_cache_round_trip_uses_key_ttl_and_logs_hit_miss(caplog) -> None:
    group_id = uuid.uuid4()
    redis = MemoryRedis()
    cache = DebtSummaryCache(redis, ttl_seconds=120)
    summary = _summary(group_id)
    caplog.set_level(logging.INFO, logger="app.services.debt_summary_cache")

    assert await cache.get(group_id) is None
    assert await cache.set(summary) is True
    assert await cache.get(group_id) == summary

    expected_key = f"group-debt-summary:v1:{group_id}"
    assert DebtSummaryCache.key(group_id) == expected_key
    assert redis.set_calls == [(expected_key, 120)]
    assert "debt_summary_cache_miss" in caplog.text
    assert "debt_summary_cache_hit" in caplog.text


@pytest.mark.asyncio
async def test_cache_read_and_write_failures_fall_back_without_raising() -> None:
    group_id = uuid.uuid4()
    cache = DebtSummaryCache(UnavailableRedis())

    assert await cache.get(group_id) is None
    assert await cache.set(_summary(group_id)) is False


@pytest.mark.asyncio
async def test_invalid_cached_payload_is_treated_as_a_miss() -> None:
    group_id = uuid.uuid4()
    redis = MemoryRedis()
    redis.values[DebtSummaryCache.key(group_id)] = "not-json"

    assert await DebtSummaryCache(redis).get(group_id) is None


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


@pytest.mark.asyncio
async def test_best_effort_invalidation_never_raises() -> None:
    cache = DebtSummaryCache(
        UnavailableRedis(),
        max_attempts=1,
        initial_delay_seconds=0,
    )

    assert await cache.invalidate_best_effort(uuid.uuid4()) is False
