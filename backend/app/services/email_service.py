import html
from email.message import EmailMessage
from typing import Protocol
from urllib.parse import urlencode, urlsplit

import aiosmtplib

from app.core.config import settings


class EmailSender(Protocol):
    async def send_verification(self, *, email: str, token: str) -> None: ...

    async def send_password_reset(self, *, email: str, token: str) -> None: ...

    async def send_group_invitation(
        self,
        *,
        email: str,
        token: str,
        group_name: str,
    ) -> None: ...

    async def send_friend_invitation(
        self,
        *,
        email: str,
        token: str,
        inviter_display_name: str,
    ) -> None: ...


class DisabledEmailSender:
    async def send_verification(self, *, email: str, token: str) -> None:
        del email, token

    async def send_password_reset(self, *, email: str, token: str) -> None:
        del email, token

    async def send_group_invitation(
        self,
        *,
        email: str,
        token: str,
        group_name: str,
    ) -> None:
        del email, token, group_name

    async def send_friend_invitation(
        self,
        *,
        email: str,
        token: str,
        inviter_display_name: str,
    ) -> None:
        del email, token, inviter_display_name


class SMTPEmailSender:
    async def send_verification(self, *, email: str, token: str) -> None:
        verification_url = self._action_url("verify-email", token)
        await self._send(
            recipient=email,
            subject="EconBuddy e-posta adresini doğrula",
            body=(
                "EconBuddy hesabını kullanmaya başlamak için e-posta adresini "
                "doğrula:\n\n"
                f"{verification_url}\n\n"
                "Bu bağlantı 24 saat geçerlidir. Bu hesabı sen oluşturmadıysan "
                "bu e-postayı yok sayabilirsin."
            ),
            html_body=(
                "<p>EconBuddy hesabını kullanmaya başlamak için e-posta adresini "
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

    async def send_group_invitation(
        self,
        *,
        email: str,
        token: str,
        group_name: str,
    ) -> None:
        invitation_url = self._group_invitation_url(token)
        web_url = self._web_landing_url("group-invitation", token)
        safe_group_name = html.escape(group_name)
        safe_web_url = html.escape(web_url, quote=True)
        await self._send(
            recipient=email,
            subject="EconBuddy grup daveti",
            body=(
                f"{group_name} grubuna davet edildin. Daveti kabul etmek için "
                "bağlantıyı aç:\n\n"
                f"{invitation_url}\n\n"
                "Bu bağlantı 24 saat geçerlidir ve yalnızca davet edilen "
                "e-posta hesabıyla kullanılabilir."
            ),
            html_body=(
                f"<p><strong>{safe_group_name}</strong> grubuna davet edildin.</p>"
                f'<p><a href="{safe_web_url}">Grup davetini kabul et</a></p>'
                "<p>Bu bağlantı 24 saat geçerlidir ve yalnızca davet edilen "
                "e-posta hesabıyla kullanılabilir.</p>"
            ),
        )

    async def send_friend_invitation(
        self,
        *,
        email: str,
        token: str,
        inviter_display_name: str,
    ) -> None:
        invitation_url = self._friend_invitation_url(token)
        web_url = self._web_landing_url("friend-invitation", token)
        safe_inviter_name = html.escape(inviter_display_name)
        safe_web_url = html.escape(web_url, quote=True)
        await self._send(
            recipient=email,
            subject="EconBuddy arkadaşlık daveti",
            body=(
                f"{inviter_display_name} seni arkadaş olarak eklemek istiyor. "
                "Daveti kabul etmek için bağlantıyı aç:\n\n"
                f"{invitation_url}\n\n"
                "Bu bağlantı 24 saat geçerlidir ve yalnızca davet edilen "
                "e-posta hesabıyla kullanılabilir."
            ),
            html_body=(
                f"<p><strong>{safe_inviter_name}</strong> seni arkadaş olarak "
                "eklemek istiyor.</p>"
                f'<p><a href="{safe_web_url}">Arkadaşlık davetini kabul et</a></p>'
                "<p>Bu bağlantı 24 saat geçerlidir ve yalnızca davet edilen "
                "e-posta hesabıyla kullanılabilir.</p>"
            ),
        )

    @staticmethod
    def _action_url(action: str, token: str) -> str:
        base_url = settings.email_action_base_url.rstrip("/")
        endpoint = {
            "verify-email": "verify-email-link",
            "reset-password": "reset-password-link",
        }.get(action, action)
        return f"{base_url}/{endpoint}?{urlencode({'token': token})}"

    @staticmethod
    def _group_invitation_url(token: str) -> str:
        base_url = settings.app_deep_link_base_url.rstrip("/")
        return f"{base_url}/group-invitation?{urlencode({'token': token})}"

    @staticmethod
    def _friend_invitation_url(token: str) -> str:
        base_url = settings.app_deep_link_base_url.rstrip("/")
        return f"{base_url}/friend-invitation?{urlencode({'token': token})}"

    @staticmethod
    def _web_landing_url(path: str, token: str) -> str:
        # E-posta istemcileri (Gmail dahil) özel URL şemalarını (fiskon://)
        # e-posta gövdesinde tıklanabilir bağlantı olarak göstermiyor. Bu yüzden
        # e-postadaki buton, önce bu https sayfasına gider; sayfa da tıklandığında
        # uygulamayı özel şema ile açar.
        origin = urlsplit(settings.email_action_base_url)
        base = f"{origin.scheme}://{origin.netloc}"
        return f"{base}/api/v1/{path}?{urlencode({'token': token})}"

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
