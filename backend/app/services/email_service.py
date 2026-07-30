from email.message import EmailMessage
from typing import Protocol
from urllib.parse import urlencode

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
        verification_url = self._action_url("verify-email", token)
        await self._send(
            recipient=email,
            subject="FisKon e-posta adresini doğrula",
            body=(
                "FisKon hesabını kullanmaya başlamak için e-posta adresini "
                "doğrula:\n\n"
                f"{verification_url}\n\n"
                "Bu bağlantı 24 saat geçerlidir. Bu hesabı sen oluşturmadıysan "
                "bu e-postayı yok sayabilirsin."
            ),
            html_body=(
                "<p>FisKon hesabını kullanmaya başlamak için e-posta adresini "
                "doğrula.</p>"
                f'<p><a href="{verification_url}">E-posta adresimi doğrula</a></p>'
                "<p>Bu bağlantı 24 saat geçerlidir. Bu hesabı sen "
                "oluşturmadıysan bu e-postayı yok sayabilirsin.</p>"
            ),
        )

    async def send_password_reset(self, *, email: str, token: str) -> None:
        reset_url = self._action_url("reset-password", token)
        await self._send(
            recipient=email,
            subject="Şifre sıfırlama",
            body=(
                "Şifreni sıfırlamak için bağlantıyı aç:\n\n"
                f"{reset_url}"
            ),
            html_body=(
                "<p>Şifreni sıfırlamak için aşağıdaki bağlantıyı aç.</p>"
                f'<p><a href="{reset_url}">Şifremi sıfırla</a></p>'
            ),
        )

    @staticmethod
    def _action_url(action: str, token: str) -> str:
        base_url = settings.app_deep_link_base_url.rstrip("/")
        return f"{base_url}/{action}?{urlencode({'token': token})}"

    async def _send(
        self,
        *,
        recipient: str,
        subject: str,
        body: str,
        html_body: str,
    ) -> None:
        message = EmailMessage()
        message["From"] = settings.email_from
        message["To"] = recipient
        message["Subject"] = subject
        message.set_content(body)
        message.add_alternative(html_body, subtype="html")

        username = (settings.smtp_user or "").strip() or None
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
            start_tls=settings.smtp_tls,
            timeout=settings.smtp_timeout_seconds,
        )


def create_email_sender() -> EmailSender:
    if settings.email_delivery_mode == "smtp":
        return SMTPEmailSender()
    return DisabledEmailSender()
