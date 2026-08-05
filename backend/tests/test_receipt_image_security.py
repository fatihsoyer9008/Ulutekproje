import asyncio
import threading
import time
from io import BytesIO
from pathlib import Path
from tempfile import NamedTemporaryFile

import pytest
from fastapi import HTTPException, UploadFile
from PIL import ExifTags, Image
from starlette.datastructures import Headers

import app.core.receipt_image_security as image_security
from app.core.config import settings


def create_jpeg_bytes_with_exif() -> bytes:
    output = BytesIO()
    image = Image.new("RGB", (2, 3), color="white")
    exif = Image.Exif()
    exif[0x010E] = "private receipt location"
    exif[0x0112] = 6
    exif[ExifTags.IFD.GPSInfo] = {
        ExifTags.GPS.GPSLatitudeRef: "N",
        ExifTags.GPS.GPSLatitude: (40.0, 0.0, 0.0),
        ExifTags.GPS.GPSLongitudeRef: "E",
        ExifTags.GPS.GPSLongitude: (29.0, 0.0, 0.0),
    }
    image.save(output, format="JPEG", exif=exif)
    image.close()
    return output.getvalue()


def temporary_upload(contents: bytes) -> tuple[UploadFile, Path]:
    temporary_file = NamedTemporaryFile(suffix=".jpg", delete=True)
    temporary_file.write(contents)
    temporary_file.flush()
    temporary_file.seek(0)
    path = Path(temporary_file.name)
    upload = UploadFile(
        file=temporary_file,
        filename="receipt.jpg",
        size=len(contents),
        headers=Headers({"content-type": "image/jpeg"}),
    )
    return upload, path


def test_image_normalization_removes_all_exif_metadata() -> None:
    original_bytes = create_jpeg_bytes_with_exif()
    with Image.open(BytesIO(original_bytes)) as original_image:
        assert original_image.getexif().get_ifd(ExifTags.IFD.GPSInfo)

    normalized_bytes = image_security._normalize_image(
        original_bytes,
        expected_mime_type="image/jpeg",
    )

    with Image.open(BytesIO(normalized_bytes)) as normalized_image:
        assert dict(normalized_image.getexif()) == {}
        assert "exif" not in normalized_image.info
        assert normalized_image.size == (3, 2)


@pytest.mark.asyncio
async def test_temporary_upload_is_deleted_after_success() -> None:
    upload, temporary_path = temporary_upload(create_jpeg_bytes_with_exif())

    await image_security.read_validated_receipt_image(upload)

    assert upload.file.closed
    assert not temporary_path.exists()


@pytest.mark.asyncio
async def test_temporary_upload_is_deleted_after_validation_error() -> None:
    upload, temporary_path = temporary_upload(b"not-an-image")

    with pytest.raises(HTTPException):
        await image_security.read_validated_receipt_image(upload)

    assert upload.file.closed
    assert not temporary_path.exists()


@pytest.mark.asyncio
async def test_image_normalization_runs_outside_event_loop_thread(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    event_loop_thread = threading.get_ident()
    worker_thread: int | None = None

    def fake_normalize(
        data: bytes,
        *,
        expected_mime_type: str,
    ) -> bytes:
        nonlocal worker_thread
        del expected_mime_type
        worker_thread = threading.get_ident()
        return data

    monkeypatch.setattr(
        image_security,
        "_normalize_image",
        fake_normalize,
    )

    result = await image_security._normalize_image_in_worker(
        b"image-bytes",
        expected_mime_type="image/jpeg",
    )

    assert result == b"image-bytes"
    assert worker_thread is not None
    assert worker_thread != event_loop_thread


@pytest.mark.asyncio
async def test_image_normalization_respects_concurrency_limit(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    active_workers = 0
    maximum_active_workers = 0
    lock = threading.Lock()

    def slow_normalize(
        data: bytes,
        *,
        expected_mime_type: str,
    ) -> bytes:
        nonlocal active_workers, maximum_active_workers
        del expected_mime_type

        with lock:
            active_workers += 1
            maximum_active_workers = max(
                maximum_active_workers,
                active_workers,
            )

        try:
            time.sleep(0.05)
            return data
        finally:
            with lock:
                active_workers -= 1

    monkeypatch.setattr(
        image_security,
        "_normalize_image",
        slow_normalize,
    )

    results = await asyncio.gather(
        *[
            image_security._normalize_image_in_worker(
                f"image-{index}".encode(),
                expected_mime_type="image/jpeg",
            )
            for index in range(settings.receipt_image_processing_concurrency + 3)
        ]
    )

    assert len(results) == settings.receipt_image_processing_concurrency + 3
    assert maximum_active_workers <= settings.receipt_image_processing_concurrency
