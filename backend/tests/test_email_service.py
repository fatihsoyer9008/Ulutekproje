from unittest.mock import AsyncMock

import pytest
from pydantic import SecretStr

from app.core.config import settings
from app.services.email_service import SMTPEmailSender


@pytest.mark.asyncio
async def test_mailpit_does_not_receive_empty_smtp_credentials(
    monkeypatch,
) -> None:
    send = AsyncMock()
    monkeypatch.setattr("app.services.email_service.aiosmtplib.send", send)
    monkeypatch.setattr(settings, "smtp_username", "")
    monkeypatch.setattr(settings, "smtp_password", SecretStr(""))
    monkeypatch.setattr(settings, "smtp_start_tls", False)

    await SMTPEmailSender().send_verification(
        email="user@example.com",
        token="verification-token",
    )

    assert send.await_args.kwargs["username"] is None
    assert send.await_args.kwargs["password"] is None
    assert send.await_args.kwargs["start_tls"] is False
