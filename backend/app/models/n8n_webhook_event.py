import uuid
from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class N8nWebhookEvent(Base):
    """Durable idempotency + replay record for inbound n8n webhook events.

    There is currently a single trusted webhook sender (one shared HMAC
    secret), so the "gönderen kapsamı" the contract describes collapses to
    the (event_type, idempotency_key) pair.
    """

    __tablename__ = "n8n_webhook_events"
    __table_args__ = (
        UniqueConstraint(
            "event_type",
            "idempotency_key",
            name="uq_n8n_webhook_events_type_key",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    event_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    response_status: Mapped[int] = mapped_column(Integer, nullable=False)
    response_body: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
