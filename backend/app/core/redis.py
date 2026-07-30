from collections.abc import AsyncIterator

from redis.asyncio import Redis

from app.core.config import settings


async def get_redis() -> AsyncIterator[Redis]:
    client = Redis.from_url(
        settings.redis_url.get_secret_value(),
        encoding="utf-8",
        decode_responses=True,
    )
    try:
        yield client
    finally:
        await client.aclose()
