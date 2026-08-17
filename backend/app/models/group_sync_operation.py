import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class GroupSyncOperation(Base):
    """Durable idempotency receipt for group sync operations without one."""

    __tablename__ = "group_sync_operations"
    __table_args__ = (
        UniqueConstraint(
            "actor_user_id",
            "client_record_id",
            name="uq_group_sync_operations_actor_record",
        ),
        Index("ix_group_sync_operations_group_id", "group_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"), nullable=False
    )
    actor_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    client_record_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    operation_type: Mapped[str] = mapped_column(String(32), nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
