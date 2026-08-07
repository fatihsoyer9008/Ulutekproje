import warnings
from dataclasses import dataclass
from functools import partial
from io import BytesIO
from pathlib import PurePath

from anyio import CapacityLimiter, to_thread
from fastapi import HTTPException, UploadFile, status
from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.config import settings

_READ_CHUNK_SIZE = 64 * 1024
_PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
_JPEG_SIGNATURE = b"\xff\xd8\xff"

_ALLOWED_EXTENSIONS = {
    "image/jpeg": {".jpg", ".jpeg"},
    "image/png": {".png"},
}
_IMAGE_PROCESSING_LIMITER = CapacityLimiter(
    settings.receipt_image_processing_concurrency
)


@dataclass(frozen=True)
class ValidatedReceiptImage:
    data: bytes
    mime_type: str


def _detect_signature_mime_type(data: bytes) -> str | None:
    if data.startswith(_PNG_SIGNATURE):
        return "image/png"
    if data.startswith(_JPEG_SIGNATURE):
        return "image/jpeg"
    return None


def _unsupported_image() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
        detail="Yalnızca geçerli JPEG veya PNG fiş görüntüleri kabul edilir.",
    )


def _image_too_large(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_413_CONTENT_TOO_LARGE,
        detail=detail,
    )


def _remove_image_metadata(image: Image.Image) -> None:
    """Remove metadata from the decoded image before it is re-encoded."""
    image.info.clear()
    image.getexif().clear()


def _normalize_image(
    data: bytes,
    *,
    expected_mime_type: str,
) -> bytes:
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)

            with Image.open(BytesIO(data)) as image:
                decoded_mime_type = Image.MIME.get(image.format or "")
                if decoded_mime_type != expected_mime_type:
                    raise _unsupported_image()

                width, height = image.size
                if width <= 0 or height <= 0:
                    raise _unsupported_image()
                if width * height > settings.receipt_image_max_pixels:
                    raise _image_too_large(
                        "Fiş görüntüsünün çözünürlüğü izin verilen sınırı aşıyor."
                    )

                image.verify()

            with Image.open(BytesIO(data)) as image:
                normalized = ImageOps.exif_transpose(image)
                try:
                    normalized.load()
                    _remove_image_metadata(normalized)
                    output = BytesIO()

                    if expected_mime_type == "image/jpeg":
                        if normalized.mode != "RGB":
                            normalized = normalized.convert("RGB")
                        normalized.save(
                            output,
                            format="JPEG",
                            quality=95,
                            optimize=True,
                        )
                    else:
                        target_mode = "RGBA" if "A" in normalized.getbands() else "RGB"
                        if normalized.mode != target_mode:
                            normalized = normalized.convert(target_mode)
                        normalized.save(
                            output,
                            format="PNG",
                            optimize=True,
                        )

                    normalized_bytes = output.getvalue()
                finally:
                    if normalized is not image:
                        normalized.close()

    except HTTPException:
        raise
    except (
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
        UnidentifiedImageError,
        OSError,
        SyntaxError,
        ValueError,
    ) as exc:
        raise _unsupported_image() from exc

    if len(normalized_bytes) > settings.receipt_image_max_bytes:
        raise _image_too_large(
            "Normalize edilen fiş görüntüsü izin verilen boyutu aşıyor."
        )

    return normalized_bytes


async def _normalize_image_in_worker(
    data: bytes,
    *,
    expected_mime_type: str,
) -> bytes:
    normalize = partial(
        _normalize_image,
        data,
        expected_mime_type=expected_mime_type,
    )
    return await to_thread.run_sync(
        normalize,
        limiter=_IMAGE_PROCESSING_LIMITER,
    )


async def read_validated_receipt_image(
    upload: UploadFile,
) -> ValidatedReceiptImage:
    """Validate and sanitize an upload, then release its temporary storage."""
    try:
        declared_mime = (upload.content_type or "").partition(";")[0].strip().casefold()
        if declared_mime not in _ALLOWED_EXTENSIONS:
            raise _unsupported_image()

        suffix = PurePath(upload.filename or "").suffix.casefold()
        if suffix not in _ALLOWED_EXTENSIONS[declared_mime]:
            raise _unsupported_image()

        if upload.size is not None and upload.size > settings.receipt_image_max_bytes:
            raise _image_too_large("Fiş görüntüsü izin verilen dosya boyutunu aşıyor.")

        contents = bytearray()
        while chunk := await upload.read(_READ_CHUNK_SIZE):
            if len(contents) + len(chunk) > settings.receipt_image_max_bytes:
                raise _image_too_large(
                    "Fiş görüntüsü izin verilen dosya boyutunu aşıyor."
                )
            contents.extend(chunk)

        if not contents:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Fiş görüntüsü boş olamaz.",
            )

        image_bytes = bytes(contents)
        signature_mime_type = _detect_signature_mime_type(image_bytes)
        if signature_mime_type != declared_mime:
            raise _unsupported_image()
        if suffix not in _ALLOWED_EXTENSIONS[signature_mime_type]:
            raise _unsupported_image()

        normalized_bytes = await _normalize_image_in_worker(
            image_bytes,
            expected_mime_type=signature_mime_type,
        )
        return ValidatedReceiptImage(
            data=normalized_bytes,
            mime_type=signature_mime_type,
        )
    finally:
        # Starlette stores multipart uploads in a SpooledTemporaryFile. Closing
        # the UploadFile here also deletes any on-disk temporary file, on both
        # successful and failed processing paths.
        await upload.close()
