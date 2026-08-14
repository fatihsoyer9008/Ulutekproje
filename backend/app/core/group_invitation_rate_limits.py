import uuid

from app.core.config import settings
from app.core.rate_limit import RateLimiter, RateLimitRule


def group_invitation_rate_limit_rules() -> tuple[
    RateLimitRule,
    RateLimitRule,
    RateLimitRule,
]:
    return (
        RateLimitRule(
            name="group-invitation-user-hourly",
            limit=settings.group_invitation_user_hourly_limit,
            window_seconds=3600,
        ),
        RateLimitRule(
            name="group-invitation-group-hourly",
            limit=settings.group_invitation_group_hourly_limit,
            window_seconds=3600,
        ),
        RateLimitRule(
            name="group-invitation-email-daily",
            limit=settings.group_invitation_email_daily_limit,
            window_seconds=86_400,
        ),
    )


async def enforce_group_invitation_rate_limits(
    *,
    limiter: RateLimiter,
    actor_user_id: uuid.UUID,
    group_id: uuid.UUID,
    invited_email: str,
) -> None:
    user_rule, group_rule, email_rule = group_invitation_rate_limit_rules()
    await limiter.enforce(
        user_rule,
        identifier=f"user:{actor_user_id}",
    )
    await limiter.enforce(
        group_rule,
        identifier=f"group:{group_id}",
    )
    await limiter.enforce(
        email_rule,
        identifier=f"email:{invited_email}",
    )
