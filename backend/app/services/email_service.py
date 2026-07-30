from email.message import EmailMessage
from typing import Protocol

import aiosmtplib

from app.core.config import settings


class EmailSender(Protocol):
    async def send_verification(self, *, email: str, token: str) -> None: ...

    async def send_password_reset(self, *, email: str, token: str) -> None: ...


class DisabledEmailSender:
    async def send_verification(self, *, email: str, token: str) -> None:
        del email, token

    async def send_password_reset(self, *, email: str, token: str) -> None:
        del email, token


class SMTPEmailSender:
    async def send_verification(self, *, email: str, token: str) -> None:
        await self._send(
            recipient=email,
            subject="E-posta adresini doğrula",
            body=(
                "E-posta adresini doğrulamak için bağlantıyı aç:\n\n"
                f"{settings.app_deep_link_base_url}/verify-email?token={token}"
            ),
        )

    async def send_password_reset(self, *, email: str, token: str) -> None:
        await self._send(
            recipient=email,
            subject="Şifre sıfırlama",
            body=(
                "Şifreni sıfırlamak için bağlantıyı aç:\n\n"
                f"{settings.app_deep_link_base_url}/reset-password?token={token}"
            ),
        )

    async def _send(
        self,
        *,
        recipient: str,
        subject: str,
        body: str,
    ) -> None:
        message = EmailMessage()
        message["From"] = settings.email_from
        message["To"] = recipient
        message["Subject"] = subject
        message.set_content(body)

        username = (settings.smtp_username or "").strip() or None
        password = (
            settings.smtp_password.get_secret_value().strip()
            if settings.smtp_password is not None
            else ""
        ) or None
        await aiosmtplib.send(
            message,
            hostname=settings.smtp_host,
            port=settings.smtp_port,
            username=username,
            password=password,
            start_tls=settings.smtp_start_tls,
        )


def create_email_sender() -> EmailSender:
    if settings.email_delivery_mode == "smtp":
        return SMTPEmailSender()
    return DisabledEmailSender()
