from app.core.config import settings
from app.core.rate_limit import RateLimiter, RateLimitRule

ASSISTANT_USER_BURST = RateLimitRule(
    name="assistant-user-burst",
    limit=settings.assistant_user_burst_limit,
    window_seconds=60,
)
ASSISTANT_USER_DAILY = RateLimitRule(
    name="assistant-user-daily",
    limit=settings.assistant_user_daily_limit,
    window_seconds=86_400,
)


async def enforce_assistant_rate_limits(
    *,
    user_id: str,
    limiter: RateLimiter,
) -> None:
    identifier = f"user:{user_id}"
    await limiter.enforce(
        ASSISTANT_USER_BURST,
        identifier=identifier,
    )
    await limiter.enforce(
        ASSISTANT_USER_DAILY,
        identifier=identifier,
    )
