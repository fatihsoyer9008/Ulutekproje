from unittest.mock import AsyncMock

import pytest
from pydantic import SecretStr

from app.core.config import Settings, settings
from app.services.email_service import SMTPEmailSender


@pytest.mark.asyncio
async def test_smtp_sender_uses_real_provider_configuration(
    monkeypatch,
) -> None:
    send = AsyncMock()
    test_credential = "".join(("unit", "-", "test", "-", "credential"))
    monkeypatch.setattr("app.services.email_service.aiosmtplib.send", send)
    monkeypatch.setattr(settings, "smtp_host", "smtp.gmail.com")
    monkeypatch.setattr(settings, "smtp_port", 587)
    monkeypatch.setattr(settings, "smtp_user", "sender@example.com")
    monkeypatch.setattr(
        settings,
        "smtp_password",
        SecretStr(test_credential),
    )
    monkeypatch.setattr(settings, "smtp_tls", True)
    monkeypatch.setattr(settings, "smtp_timeout_seconds", 15.0)
    monkeypatch.setattr(
        settings,
        "email_action_base_url",
        "https://api.example.com/api/v1/auth",
    )

    await SMTPEmailSender().send_verification(
        email="user@example.com",
        token="verification-token",
    )

    message = send.await_args.args[0]
    plain_body = message.get_body(preferencelist=("plain",))
    assert plain_body is not None
    assert (
        "https://api.example.com/api/v1/auth/"
        "verify-email-link?token=verification-token"
        in plain_body.get_content()
    )
    assert send.await_args.kwargs["hostname"] == "smtp.gmail.com"
    assert send.await_args.kwargs["port"] == 587
    assert send.await_args.kwargs["username"] == "sender@example.com"
    assert send.await_args.kwargs["password"] == test_credential
    assert send.await_args.kwargs["start_tls"] is True
    assert send.await_args.kwargs["timeout"] == 15.0


def test_legacy_smtp_variable_names_remain_supported() -> None:
    configured = Settings(
        _env_file=None,
        SMTP_USERNAME="legacy-user",
        SMTP_START_TLS="false",
    )

    assert configured.smtp_user == "legacy-user"
    assert configured.smtp_tls is False
