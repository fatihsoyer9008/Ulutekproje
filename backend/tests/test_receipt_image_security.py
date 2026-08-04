import asyncio
import threading
import time

import pytest

import app.core.receipt_image_security as image_security
from app.core.config import settings


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
