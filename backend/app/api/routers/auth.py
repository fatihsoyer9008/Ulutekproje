import html
import json
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import HTMLResponse
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_apple_oauth_provider,
    get_current_user,
    get_email_sender,
    get_google_oauth_verifier,
    get_oauth_token_cipher,
    get_rate_limiter,
    request_ip,
    session_metadata,
)
from app.auth_schemas import (
    AppleOAuthRequest,
    DeleteAccountRequest,
    EmailRequest,
    GoogleOAuthRequest,
    LoginRequest,
    LogoutRequest,
    MessageResponse,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenPairResponse,
    UserResponse,
    VerifyEmailRequest,
)
from app.core.database import get_db_session
from app.core.oauth_crypto import OAuthTokenCipher, OAuthTokenEncryptionError
from app.core.rate_limit import RateLimiter, RateLimitRule
from app.core.security import normalize_email
from app.models.user import User
from app.services.apple_oauth import AppleOAuthProvider
from app.services.auth_service import (
    AccountDeletionFailed,
    AuthService,
    EmailAlreadyRegistered,
    EmailNotVerified,
    InvalidCredentials,
    InvalidOneTimeToken,
    ReauthenticationRequired,
)
from app.services.email_service import EmailSender
from app.services.google_oauth import GoogleOAuthVerifier
from app.services.oauth_service import AccountLinkingRequired, OAuthLoginService
from app.services.oauth_types import (
    OAuthConfigurationError,
    OAuthProviderError,
    OAuthValidationError,
)
from app.services.session_service import (
    InvalidRefreshToken,
    RefreshTokenReuseDetected,
    SessionService,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])
logger = logging.getLogger(__name__)

REGISTER_IP = RateLimitRule("register-ip", 5, 3600)
REGISTER_EMAIL = RateLimitRule("register-email", 3, 3600)
LOGIN_IP = RateLimitRule("login-ip", 20, 900)
LOGIN_EMAIL = RateLimitRule("login-email", 10, 900)
OAUTH_IP = RateLimitRule("oauth-ip", 15, 900)
REFRESH_IP = RateLimitRule("refresh-ip", 60, 60)
LOGOUT_IP = RateLimitRule("logout-ip", 60, 60)
TOKEN_ACTION_IP = RateLimitRule("token-action-ip", 20, 3600)
EMAIL_IP = RateLimitRule("email-action-ip", 10, 3600)
EMAIL_ADDRESS = RateLimitRule("email-action-address", 3, 3600)

GENERIC_REGISTER_MESSAGE = (
    "If the address is eligible, a verification email will be sent."
)
GENERIC_EMAIL_MESSAGE = (
    "If the address is eligible, an email with the next step will be sent."
)


def _token_response(issued) -> TokenPairResponse:
    return TokenPairResponse(
        access_token=issued.access_token,
        refresh_token=issued.refresh_token,
        expires_in=issued.expires_in,
        user=UserResponse.from_user(issued.user),
    )


async def _email_limits(
    *,
    limiter: RateLimiter,
    request: Request,
    email: str,
    ip_rule: RateLimitRule,
    email_rule: RateLimitRule,
) -> None:
    await limiter.enforce(ip_rule, identifier=f"ip:{request_ip(request)}")
    await limiter.enforce(
        email_rule,
        identifier=f"email:{normalize_email(email)}",
    )


@router.post(
    "/register",
    response_model=MessageResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def register(
    payload: RegisterRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    email_sender: EmailSender = Depends(get_email_sender),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> MessageResponse:
    await _email_limits(
        limiter=limiter,
        request=request,
        email=str(payload.email),
        ip_rule=REGISTER_IP,
        email_rule=REGISTER_EMAIL,
    )
    try:
        await AuthService(db, email_sender).register(
            email=str(payload.email),
            password=payload.password,
            display_name=payload.display_name,
        )
    except EmailAlreadyRegistered:
        # Registration must not disclose whether an account exists. Keep the
        # public status and response identical to a new registration while the
        # service avoids sending another verification email or changing the
        # existing account.
        pass
    return MessageResponse(message=GENERIC_REGISTER_MESSAGE)


@router.post("/login", response_model=TokenPairResponse)
async def login(
    payload: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    email_sender: EmailSender = Depends(get_email_sender),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> TokenPairResponse:
    await _email_limits(
        limiter=limiter,
        request=request,
        email=str(payload.email),
        ip_rule=LOGIN_IP,
        email_rule=LOGIN_EMAIL,
    )
    try:
        issued = await AuthService(db, email_sender).login(
            email=str(payload.email),
            password=payload.password,
            metadata=session_metadata(
                request,
                device_id=payload.device_id,
                device_name=payload.device_name,
            ),
        )
    except InvalidCredentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        ) from None
    except EmailNotVerified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "email_not_verified",
                "message": (
                    "E-posta adresi henüz doğrulanmadı. "
                    "Doğrulama bağlantısını kontrol edin."
                ),
            },
        ) from None
    return _token_response(issued)


@router.post("/google", response_model=TokenPairResponse)
async def google_login(
    payload: GoogleOAuthRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    verifier: GoogleOAuthVerifier = Depends(get_google_oauth_verifier),
    token_cipher: OAuthTokenCipher = Depends(get_oauth_token_cipher),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> TokenPairResponse:
    await limiter.enforce(OAUTH_IP, identifier=f"ip:{request_ip(request)}")
    try:
        identity = verifier.verify(id_token=payload.id_token, nonce=payload.nonce)
        issued = await OAuthLoginService(
            db,
            token_cipher=token_cipher,
        ).login_or_register(
            identity=identity,
            metadata=session_metadata(
                request,
                device_id=payload.device_id,
                device_name=payload.device_name,
            ),
        )
    except AccountLinkingRequired:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "google_account_already_exists",
                "message": (
                    "Bu e-posta adresiyle mevcut bir hesap var. Güvenlik için "
                    "önce e-posta ve şifrenizle giriş yapın."
                ),
            },
        ) from None
    except (OAuthConfigurationError, OAuthTokenEncryptionError) as exc:
        logger.error("Google OAuth configuration error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "google_oauth_not_configured",
                "message": (
                    "Google OAuth is not configured on the server. "
                    "Set GOOGLE_OAUTH_CLIENT_IDS to the same web client ID "
                    "used by Flutter."
                ),
            },
        ) from None
    except OAuthValidationError as exc:
        logger.warning("Google OAuth validation rejected: code=%s", exc.code)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": exc.code, "message": str(exc)},
        ) from None
    except SQLAlchemyError:
        await db.rollback()
        logger.exception("Google OAuth database operation failed")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "google_account_persistence_failed",
                "message": (
                    "Google account could not be saved. "
                    "Please try again after the database is available."
                ),
            },
        ) from None
    return _token_response(issued)


@router.post("/apple", response_model=TokenPairResponse)
async def apple_login(
    payload: AppleOAuthRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    provider: AppleOAuthProvider = Depends(get_apple_oauth_provider),
    token_cipher: OAuthTokenCipher = Depends(get_oauth_token_cipher),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> TokenPairResponse:
    await limiter.enforce(OAUTH_IP, identifier=f"ip:{request_ip(request)}")
    try:
        identity = await provider.authenticate(
            identity_token=payload.identity_token,
            authorization_code=payload.authorization_code,
            nonce=payload.nonce,
        )
        issued = await OAuthLoginService(
            db,
            token_cipher=token_cipher,
        ).login_or_register(
            identity=identity,
            metadata=session_metadata(
                request,
                device_id=payload.device_id,
                device_name=payload.device_name,
            ),
        )
    except AccountLinkingRequired as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from None
    except (OAuthConfigurationError, OAuthTokenEncryptionError):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Apple OAuth is not configured.",
        ) from None
    except OAuthProviderError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Apple authentication service is unavailable.",
        ) from None
    except OAuthValidationError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple authentication failed.",
        ) from None
    return _token_response(issued)


@router.post("/refresh", response_model=TokenPairResponse)
async def refresh(
    payload: RefreshRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> TokenPairResponse:
    await limiter.enforce(
        REFRESH_IP,
        identifier=f"ip:{request_ip(request)}",
    )
    try:
        issued = await SessionService(db).rotate(
            refresh_token=payload.refresh_token,
            metadata=session_metadata(
                request,
                device_id=payload.device_id,
                device_name=payload.device_name,
            ),
        )
    except RefreshTokenReuseDetected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session security violation detected. Sign in again.",
        ) from None
    except InvalidRefreshToken:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token.",
        ) from None
    return _token_response(issued)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    payload: LogoutRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> Response:
    await limiter.enforce(
        LOGOUT_IP,
        identifier=f"ip:{request_ip(request)}",
    )
    await SessionService(db).logout(
        refresh_token=payload.refresh_token,
        all_devices=payload.all_devices,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserResponse)
async def me(user: User = Depends(get_current_user)) -> UserResponse:
    return UserResponse.from_user(user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(
    payload: DeleteAccountRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
    email_sender: EmailSender = Depends(get_email_sender),
    apple_provider: AppleOAuthProvider = Depends(get_apple_oauth_provider),
    token_cipher: OAuthTokenCipher = Depends(get_oauth_token_cipher),
) -> Response:
    try:
        await AuthService(db, email_sender).delete_account(
            user=user,
            current_password=payload.current_password,
            apple_provider=apple_provider,
            token_cipher=token_cipher,
        )
    except ReauthenticationRequired:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Reauthentication is required.",
        ) from None
    except AccountDeletionFailed:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Provider revocation is pending; account access was disabled.",
        ) from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/verify-email", response_model=MessageResponse)
async def verify_email(
    payload: VerifyEmailRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    email_sender: EmailSender = Depends(get_email_sender),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> MessageResponse:
    await limiter.enforce(
        TOKEN_ACTION_IP,
        identifier=f"ip:{request_ip(request)}",
    )
    try:
        await AuthService(db, email_sender).verify_email(payload.token)
    except InvalidOneTimeToken:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification token.",
        ) from None
    return MessageResponse(message="Email address verified.")


@router.get(
    "/verify-email-link",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def verify_email_link(
    request: Request,
    token: str = Query(min_length=32, max_length=512),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> HTMLResponse:
    await limiter.enforce(
        TOKEN_ACTION_IP,
        identifier=f"ip:{request_ip(request)}",
    )
    return _verification_confirmation_page(token)


@router.post(
    "/verify-email-link",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def confirm_verify_email_link(
    request: Request,
    token: str = Query(min_length=32, max_length=512),
    db: AsyncSession = Depends(get_db_session),
    email_sender: EmailSender = Depends(get_email_sender),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> HTMLResponse:
    await limiter.enforce(
        TOKEN_ACTION_IP,
        identifier=f"ip:{request_ip(request)}",
    )
    try:
        await AuthService(db, email_sender).verify_email(token)
    except InvalidOneTimeToken:
        return _verification_page(
            title="Bağlantı geçersiz",
            message=(
                "Bu doğrulama bağlantısının süresi dolmuş veya bağlantı "
                "daha önce kullanılmış. Uygulamadan yeni bir bağlantı isteyin."
            ),
            successful=False,
        )
    return _verification_page(
        title="E-posta doğrulandı",
        message=(
            "E-posta adresiniz başarıyla doğrulandı. FisKon uygulamasına "
            "dönüp “Doğrulandım / Devam Et” butonuna basabilirsiniz."
        ),
        successful=True,
    )


def _verification_confirmation_page(token: str) -> HTMLResponse:
    escaped_token = html.escape(token, quote=True)
    content = f"""<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>E-posta doğrulama | FisKon</title>
</head>
<body style="margin:0;background:#f3faf7;font-family:Arial,sans-serif;color:#17312b">
  <main style="max-width:560px;margin:64px auto;padding:24px">
    <section style="background:white;border-radius:24px;padding:40px;
      box-shadow:0 12px 40px rgba(22,133,107,.12);text-align:center">
      <h1 style="margin:0 0 16px;color:#16856b">E-posta adresini doğrula</h1>
      <p style="font-size:17px;line-height:1.6;margin:0 0 24px">
        Bu işlem yalnızca aşağıdaki butona bastığınızda tamamlanacaktır.
      </p>
      <form method="post"
        action="/api/v1/auth/verify-email-link?token={escaped_token}">
        <button type="submit" style="border:0;border-radius:14px;padding:14px 24px;
          background:#16856b;color:white;font-size:16px;font-weight:bold;cursor:pointer">
          E-posta adresimi doğrula
        </button>
      </form>
    </section>
  </main>
</body>
</html>"""
    return HTMLResponse(
        content=content,
        headers={
            "Cache-Control": "no-store",
            "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'",
            "Referrer-Policy": "no-referrer",
        },
    )


def _verification_page(
    *,
    title: str,
    message: str,
    successful: bool,
) -> HTMLResponse:
    color = "#16856b" if successful else "#b42318"
    icon = "✓" if successful else "!"
    content = f"""<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title} | FisKon</title>
</head>
<body style="margin:0;background:#f3faf7;font-family:Arial,sans-serif;color:#17312b">
  <main style="max-width:560px;margin:64px auto;padding:24px">
    <section style="background:white;border-radius:24px;padding:40px;
      box-shadow:0 12px 40px rgba(22,133,107,.12);text-align:center">
      <div style="width:64px;height:64px;margin:0 auto 20px;border-radius:50%;
        background:{color};color:white;font-size:40px;line-height:64px">{icon}</div>
      <h1 style="margin:0 0 16px;color:{color}">{title}</h1>
      <p style="font-size:17px;line-height:1.6;margin:0">{message}</p>
    </section>
  </main>
</body>
</html>"""
    return HTMLResponse(
        content=content,
        status_code=200 if successful else 400,
        headers={"Cache-Control": "no-store"},
    )


@router.post(
    "/resend-verification",
    response_model=MessageResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def resend_verification(
    payload: EmailRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    email_sender: EmailSender = Depends(get_email_sender),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> MessageResponse:
    await _email_limits(
        limiter=limiter,
        request=request,
        email=str(payload.email),
        ip_rule=EMAIL_IP,
        email_rule=EMAIL_ADDRESS,
    )
    await AuthService(db, email_sender).resend_verification(str(payload.email))
    return MessageResponse(message=GENERIC_EMAIL_MESSAGE)


@router.post(
    "/forgot-password",
    response_model=MessageResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def forgot_password(
    payload: EmailRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    email_sender: EmailSender = Depends(get_email_sender),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> MessageResponse:
    await _email_limits(
        limiter=limiter,
        request=request,
        email=str(payload.email),
        ip_rule=EMAIL_IP,
        email_rule=EMAIL_ADDRESS,
    )
    await AuthService(db, email_sender).forgot_password(str(payload.email))
    return MessageResponse(message=GENERIC_EMAIL_MESSAGE)


@router.get(
    "/reset-password-link",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def reset_password_link(
    request: Request,
    token: str = Query(min_length=32, max_length=512),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> HTMLResponse:
    await limiter.enforce(
        TOKEN_ACTION_IP,
        identifier=f"ip:{request_ip(request)}",
    )
    return _password_reset_page(token)


def _password_reset_page(token: str) -> HTMLResponse:
    token_json = json.dumps(token).replace("</", "<\\/")
    content = f"""<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Şifre sıfırlama | FisKon</title>
</head>
<body style="margin:0;background:#f3faf7;font-family:Arial,sans-serif;color:#17312b">
  <main style="max-width:560px;margin:64px auto;padding:24px">
    <section style="background:white;border-radius:24px;padding:40px;
      box-shadow:0 12px 40px rgba(22,133,107,.12)">
      <h1 style="margin:0 0 16px;color:#16856b">Yeni şifreni belirle</h1>
      <form id="reset-form">
        <label for="password">Yeni şifre</label>
        <input id="password" name="password" type="password" minlength="12"
          autocomplete="new-password" required
          style="box-sizing:border-box;width:100%;margin:8px 0 18px;padding:14px;
          border:1px solid #8aa79f;border-radius:12px;font-size:16px">
        <button type="submit" style="width:100%;border:0;border-radius:14px;
          padding:14px 24px;background:#16856b;color:white;font-size:16px;
          font-weight:bold;cursor:pointer">Şifremi sıfırla</button>
      </form>
      <p id="result" role="status" style="font-size:16px;line-height:1.5"></p>
    </section>
  </main>
  <script>
    const token = {token_json};
    const form = document.getElementById('reset-form');
    const result = document.getElementById('result');
    form.addEventListener('submit', async (event) => {{
      event.preventDefault();
      result.textContent = 'Şifreniz güncelleniyor...';
      const response = await fetch('/api/v1/auth/reset-password', {{
        method: 'POST',
        headers: {{'Content-Type': 'application/json'}},
        body: JSON.stringify({{
          token,
          new_password: document.getElementById('password').value
        }})
      }});
      if (response.ok) {{
        form.hidden = true;
        result.textContent = 'Şifreniz güncellendi. Uygulamadan giriş yapabilirsiniz.';
      }} else {{
        result.textContent = response.status === 400
          ? 'Bu bağlantı geçersiz, kullanılmış veya süresi dolmuş.'
          : 'Şifre güncellenemedi. Lütfen bilgileri kontrol edip tekrar deneyin.';
      }}
    }});
  </script>
</body>
</html>"""
    return HTMLResponse(
        content=content,
        headers={
            "Cache-Control": "no-store",
            "Content-Security-Policy": (
                "default-src 'none'; style-src 'unsafe-inline'; "
                "script-src 'unsafe-inline'; connect-src 'self'"
            ),
            "Referrer-Policy": "no-referrer",
        },
    )


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    payload: ResetPasswordRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    email_sender: EmailSender = Depends(get_email_sender),
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> MessageResponse:
    await limiter.enforce(
        TOKEN_ACTION_IP,
        identifier=f"ip:{request_ip(request)}",
    )
    try:
        await AuthService(db, email_sender).reset_password(
            token=payload.token,
            new_password=payload.new_password,
        )
    except InvalidOneTimeToken:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token.",
        ) from None
    return MessageResponse(message="Password has been reset.")
