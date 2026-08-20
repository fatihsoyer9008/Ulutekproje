from dataclasses import dataclass

from fastapi import HTTPException, status
from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.core.config import settings
from app.core.security import privacy_hash

_RATE_LIMIT_SCRIPT = """
local current = redis.call('INCR', KEYS[1])
if current == 1 then
  redis.call('EXPIRE', KEYS[1], ARGV[1])
end
local ttl = redis.call('TTL', KEYS[1])
return {current, ttl}
"""


@dataclass(frozen=True)
class RateLimitRule:
    name: str
    limit: int
    window_seconds: int


class RateLimiter:
    def __init__(self, redis: Redis) -> None:
        self._redis = redis

    async def enforce(
        self,
        rule: RateLimitRule,
        *,
        identifier: str,
    ) -> None:
        if not settings.rate_limit_enabled:
            return

        key = f"rate-limit:{rule.name}:{privacy_hash(identifier)}"
        try:
            current, ttl = await self._redis.eval(
                _RATE_LIMIT_SCRIPT,
                1,
                key,
                rule.window_seconds,
            )

        except RedisError as exc:
            # Protected endpoints must fail closed when Redis is unavailable.
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="İstek koruması geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.",
            ) from exc

        if int(current) > rule.limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Çok fazla istek gönderildi. Lütfen daha sonra tekrar deneyin.",
                headers={"Retry-After": str(max(int(ttl), 1))},
            )


class NoOpRateLimiter(RateLimiter):
    def __init__(self) -> None:
        pass

    async def enforce(
        self,
        rule: RateLimitRule,
        *,
        identifier: str,
    ) -> None:
        del rule, identifier
