from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    get_email_sender,
    get_rate_limiter,
    request_ip,
    session_metadata,
)
from app.auth_schemas import (
    DeleteAccountRequest,
    EmailRequest,
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
from app.core.rate_limit import RateLimiter, RateLimitRule
from app.core.security import normalize_email
from app.models.user import User
from app.services.auth_service import (
    AuthService,
    InvalidCredentials,
    InvalidOneTimeToken,
    ReauthenticationRequired,
)
from app.services.email_service import EmailSender
from app.services.session_service import (
    InvalidRefreshToken,
    RefreshTokenReuseDetected,
    SessionService,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

REGISTER_IP = RateLimitRule("register-ip", 5, 3600)
REGISTER_EMAIL = RateLimitRule("register-email", 3, 3600)
LOGIN_IP = RateLimitRule("login-ip", 20, 900)
LOGIN_EMAIL = RateLimitRule("login-email", 10, 900)
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
    await AuthService(db, email_sender).register(
        email=str(payload.email),
        password=payload.password,
        display_name=payload.display_name,
    )
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
) -> Response:
    try:
        await AuthService(db, email_sender).delete_account(
            user=user,
            current_password=payload.current_password,
        )
    except ReauthenticationRequired:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Reauthentication is required.",
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
