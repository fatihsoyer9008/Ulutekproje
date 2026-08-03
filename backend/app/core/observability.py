import logging
import re
import traceback
from collections.abc import Iterable
from uuid import uuid4

REQUEST_ID_HEADER = "X-Request-ID"
PROCESS_TIME_HEADER = "X-Process-Time-Ms"

_REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9._:-]{8,128}$")
_EMAIL_PATTERN = re.compile(
    r"(?<![A-Za-z0-9._%+-])[A-Za-z0-9._%+-]+@"
    r"(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,63}",
    re.IGNORECASE,
)


def redact_personal_data(value: object) -> str:
    return _EMAIL_PATTERN.sub("<redacted-email>", str(value))


def resolve_request_id(candidate: str | None) -> str:
    if candidate:
        normalized = candidate.strip()
        if _REQUEST_ID_PATTERN.fullmatch(normalized):
            return normalized
    return uuid4().hex


class PersonalDataRedactionFilter(logging.Filter):
    """Redact e-mail addresses before a log record reaches a handler."""

    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = redact_personal_data(record.getMessage())
        record.args = ()
        if record.exc_info is not None:
            record.exc_text = redact_personal_data(
                "".join(traceback.format_exception(*record.exc_info))
            )
            record.exc_info = None
        if record.stack_info:
            record.stack_info = redact_personal_data(record.stack_info)
        return True


def _handlers_for(loggers: Iterable[logging.Logger]) -> set[logging.Handler]:
    return {handler for logger in loggers for handler in logger.handlers}


def configure_personal_data_redaction() -> None:
    application_logger = logging.getLogger("app")
    application_logger.setLevel(logging.INFO)
    uvicorn_error_logger = logging.getLogger("uvicorn.error")
    if uvicorn_error_logger.handlers:
        application_logger.handlers = list(uvicorn_error_logger.handlers)
        application_logger.propagate = False

    loggers = (
        logging.getLogger(),
        application_logger,
        logging.getLogger("uvicorn"),
        logging.getLogger("uvicorn.access"),
        uvicorn_error_logger,
    )
    for handler in _handlers_for(loggers):
        if any(
            isinstance(item, PersonalDataRedactionFilter) for item in handler.filters
        ):
            continue
        handler.addFilter(PersonalDataRedactionFilter())
