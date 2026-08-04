from app.core.config import settings
from app.core.rate_limit import RateLimiter, RateLimitRule

RECEIPT_IP_BURST = RateLimitRule(
    name="receipt-ip-burst",
    limit=settings.receipt_ip_burst_limit,
    window_seconds=60,
)
RECEIPT_IP_DAILY = RateLimitRule(
    name="receipt-ip-daily",
    limit=settings.receipt_ip_daily_limit,
    window_seconds=86_400,
)
RECEIPT_INSTALLATION_BURST = RateLimitRule(
    name="receipt-installation-burst",
    limit=settings.receipt_installation_burst_limit,
    window_seconds=60,
)
RECEIPT_INSTALLATION_DAILY = RateLimitRule(
    name="receipt-installation-daily",
    limit=settings.receipt_installation_daily_limit,
    window_seconds=86_400,
)


async def enforce_receipt_rate_limits(
    *,
    client_ip: str,
    installation_id: str | None,
    limiter: RateLimiter,
) -> None:
    ip_identifier = f"ip:{client_ip}"

    await limiter.enforce(
        RECEIPT_IP_BURST,
        identifier=ip_identifier,
    )
    await limiter.enforce(
        RECEIPT_IP_DAILY,
        identifier=ip_identifier,
    )

    if installation_id is None:
        return

    installation_identifier = f"installation:{installation_id}"

    await limiter.enforce(
        RECEIPT_INSTALLATION_BURST,
        identifier=installation_identifier,
    )
    await limiter.enforce(
        RECEIPT_INSTALLATION_DAILY,
        identifier=installation_identifier,
    )