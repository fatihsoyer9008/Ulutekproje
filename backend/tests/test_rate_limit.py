from typing import cast

import pytest
from fastapi import HTTPException
from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.core.config import settings
from app.core.rate_limit import RateLimiter, RateLimitRule


class FakeRedis:
    def __init__(self, result: list[int]) -> None:
        self.result = result
        self.calls: list[tuple[object, ...]] = []

    async def eval(self, *args: object) -> list[int]:
        self.calls.append(args)
        return self.result


class FailingRedis:
    async def eval(self, *args: object) -> list[int]:
        del args
        raise RedisError("Redis unavailable")


@pytest.fixture(autouse=True)
def enable_rate_limit(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "rate_limit_enabled", True)


@pytest.mark.asyncio
async def test_rate_limiter_hashes_identifier_and_uses_window() -> None:
    redis = FakeRedis([1, 60])
    limiter = RateLimiter(cast(Redis, redis))
    rule = RateLimitRule(
        name="receipt-ip-burst",
        limit=10,
        window_seconds=60,
    )
    identifier = "ip:203.0.113.10"

    await limiter.enforce(rule, identifier=identifier)

    assert len(redis.calls) == 1

    script, key_count, key, window = redis.calls[0]

    assert isinstance(script, str)
    assert key_count == 1
    assert isinstance(key, str)
    assert key.startswith("rate-limit:receipt-ip-burst:")
    assert identifier not in key
    assert window == 60


@pytest.mark.asyncio
async def test_rate_limiter_allows_request_at_limit() -> None:
    redis = FakeRedis([5, 25])
    limiter = RateLimiter(cast(Redis, redis))
    rule = RateLimitRule(
        name="receipt-installation-burst",
        limit=5,
        window_seconds=60,
    )

    await limiter.enforce(
        rule,
        identifier="installation:installation-1234567890",
    )


@pytest.mark.asyncio
async def test_rate_limiter_rejects_request_above_limit() -> None:
    redis = FakeRedis([6, 42])
    limiter = RateLimiter(cast(Redis, redis))
    rule = RateLimitRule(
        name="receipt-installation-burst",
        limit=5,
        window_seconds=60,
    )

    with pytest.raises(HTTPException) as error:
        await limiter.enforce(
            rule,
            identifier="installation:installation-1234567890",
        )

    assert error.value.status_code == 429
    assert error.value.detail == (
        "Too many requests. Please try again later."
    )
    assert error.value.headers == {"Retry-After": "42"}


@pytest.mark.asyncio
async def test_rate_limiter_fails_closed_when_redis_is_unavailable() -> None:
    redis = FailingRedis()
    limiter = RateLimiter(cast(Redis, redis))
    rule = RateLimitRule(
        name="receipt-ip-daily",
        limit=50,
        window_seconds=86_400,
    )

    with pytest.raises(HTTPException) as error:
        await limiter.enforce(
            rule,
            identifier="ip:203.0.113.10",
        )

    assert error.value.status_code == 503
    assert error.value.detail == (
        "Request protection is temporarily unavailable."
    )