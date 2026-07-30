from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12, max_length=128)
    display_name: str | None = Field(default=None, min_length=1, max_length=120)

    @field_validator("display_name")
    @classmethod
    def normalize_display_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip()


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
    device_id: str | None = Field(default=None, max_length=255)
    device_name: str | None = Field(default=None, max_length=160)


class GoogleOAuthRequest(BaseModel):
    id_token: str = Field(min_length=32, max_length=8192)
    nonce: str = Field(min_length=16, max_length=512)
    device_id: str | None = Field(default=None, max_length=255)
    device_name: str | None = Field(default=None, max_length=160)


class AppleOAuthRequest(BaseModel):
    identity_token: str = Field(min_length=32, max_length=8192)
    authorization_code: str = Field(min_length=8, max_length=4096)
    nonce: str = Field(min_length=16, max_length=512)
    device_id: str | None = Field(default=None, max_length=255)
    device_name: str | None = Field(default=None, max_length=160)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=32, max_length=512)
    device_id: str | None = Field(default=None, max_length=255)
    device_name: str | None = Field(default=None, max_length=160)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=32, max_length=512)
    all_devices: bool = False


class VerifyEmailRequest(BaseModel):
    token: str = Field(min_length=32, max_length=512)


class EmailRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=32, max_length=512)
    new_password: str = Field(min_length=12, max_length=128)


class DeleteAccountRequest(BaseModel):
    current_password: str | None = Field(default=None, max_length=128)


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    display_name: str | None
    is_email_verified: bool

    @classmethod
    def from_user(cls, user) -> "UserResponse":
        return cls(
            id=str(user.id),
            email=user.email,
            display_name=user.display_name,
            is_email_verified=user.is_email_verified,
        )


class TokenPairResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse


class MessageResponse(BaseModel):
    message: str
