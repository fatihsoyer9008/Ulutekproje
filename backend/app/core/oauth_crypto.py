from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings


class OAuthTokenEncryptionError(RuntimeError):
    pass


class OAuthTokenCipher:
    """Encrypts provider refresh tokens before they reach persistent storage."""

    def __init__(self, key: str | bytes | None = None) -> None:
        configured = key
        if configured is None and settings.apple_token_encryption_key is not None:
            configured = settings.apple_token_encryption_key.get_secret_value()
        if configured is None:
            self._fernet: Fernet | None = None
            return
        encoded = configured.encode("utf-8") if isinstance(configured, str) else configured
        try:
            self._fernet = Fernet(encoded)
        except (TypeError, ValueError) as exc:
            raise OAuthTokenEncryptionError(
                "APPLE_TOKEN_ENCRYPTION_KEY is not a valid Fernet key"
            ) from exc

    def encrypt(self, plaintext: str) -> bytes:
        if self._fernet is None:
            raise OAuthTokenEncryptionError(
                "Apple token encryption is not configured"
            )
        return self._fernet.encrypt(plaintext.encode("utf-8"))

    def decrypt(self, ciphertext: bytes) -> str:
        if self._fernet is None:
            raise OAuthTokenEncryptionError(
                "Apple token encryption is not configured"
            )
        try:
            return self._fernet.decrypt(ciphertext).decode("utf-8")
        except InvalidToken as exc:
            raise OAuthTokenEncryptionError(
                "Stored Apple token could not be decrypted"
            ) from exc
