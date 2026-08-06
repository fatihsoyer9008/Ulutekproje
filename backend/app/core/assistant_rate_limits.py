from app.core.config import settings
from app.core.rate_limit import RateLimiter, RateLimitRule


def assistant_rate_limit_rules() -> tuple[RateLimitRule, RateLimitRule]:
    """Build AI-specific quota rules from the active application settings.

    Keeping these rules separate from receipt parsing prevents one feature from
    consuming the other feature's Gemini quota. Building them at enforcement
    time also keeps settings overrides deterministic in tests and deployments.
    """
    return (
        RateLimitRule(
            name="assistant-user-burst",
            limit=settings.assistant_user_burst_limit,
            window_seconds=60,
        ),
        RateLimitRule(
            name="assistant-user-daily",
            limit=settings.assistant_user_daily_limit,
            window_seconds=86_400,
        ),
    )


async def enforce_assistant_rate_limits(
    *,
    user_id: str,
    limiter: RateLimiter,
) -> None:
    identifier = f"user:{user_id}"
    for rule in assistant_rate_limit_rules():
        await limiter.enforce(rule, identifier=identifier)
