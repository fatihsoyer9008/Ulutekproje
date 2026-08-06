from dataclasses import dataclass, field

import pytest

from app.core.assistant_rate_limits import enforce_assistant_rate_limits
from app.core.config import settings
from app.core.rate_limit import RateLimitRule


@dataclass
class RecordingRateLimiter:
    calls: list[tuple[RateLimitRule, str]] = field(default_factory=list)

    async def enforce(
        self,
        rule: RateLimitRule,
        *,
        identifier: str,
    ) -> None:
        self.calls.append((rule, identifier))


@pytest.mark.asyncio
async def test_assistant_uses_separate_burst_and_daily_user_quotas(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "assistant_user_burst_limit", 3)
    monkeypatch.setattr(settings, "assistant_user_daily_limit", 17)
    limiter = RecordingRateLimiter()

    await enforce_assistant_rate_limits(
        user_id="user-123",
        limiter=limiter,  # type: ignore[arg-type]
    )

    assert [(rule.name, rule.limit, rule.window_seconds) for rule, _ in limiter.calls] == [
        ("assistant-user-burst", 3, 60),
        ("assistant-user-daily", 17, 86_400),
    ]
    assert [identifier for _, identifier in limiter.calls] == [
        "user:user-123",
        "user:user-123",
    ]


@pytest.mark.asyncio
async def test_assistant_quota_isolated_per_user() -> None:
    limiter = RecordingRateLimiter()

    await enforce_assistant_rate_limits(
        user_id="first-user",
        limiter=limiter,  # type: ignore[arg-type]
    )
    await enforce_assistant_rate_limits(
        user_id="second-user",
        limiter=limiter,  # type: ignore[arg-type]
    )

    identifiers = [identifier for _, identifier in limiter.calls]
    assert identifiers[:2] == ["user:first-user", "user:first-user"]
    assert identifiers[2:] == ["user:second-user", "user:second-user"]
