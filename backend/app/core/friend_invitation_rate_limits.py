import uuid

from app.core.config import settings
from app.core.rate_limit import RateLimiter, RateLimitRule


def friend_invitation_rate_limit_rules() -> tuple[RateLimitRule, RateLimitRule]:
    return (
        RateLimitRule(
            name="friend-invitation-user-hourly",
            limit=settings.friend_invitation_user_hourly_limit,
            window_seconds=3600,
        ),
        RateLimitRule(
            name="friend-invitation-email-daily",
            limit=settings.friend_invitation_email_daily_limit,
            window_seconds=86_400,
        ),
    )


async def enforce_friend_invitation_rate_limits(
    *,
    limiter: RateLimiter,
    actor_user_id: uuid.UUID,
    invited_email: str,
) -> None:
    user_rule, email_rule = friend_invitation_rate_limit_rules()
    await limiter.enforce(
        user_rule,
        identifier=f"user:{actor_user_id}",
    )
    await limiter.enforce(
        email_rule,
        identifier=f"email:{invited_email}",
    )
