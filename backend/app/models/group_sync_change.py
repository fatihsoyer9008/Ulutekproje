import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    JSON,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class GroupSyncChange(Base):
    """Append-only change feed consumed by group sync pull clients."""

    __tablename__ = "group_sync_changes"
    __table_args__ = (
        UniqueConstraint(
            "actor_user_id",
            "client_record_id",
            name="uq_group_sync_changes_actor_record",
        ),
        Index("ix_group_sync_changes_group_sequence", "group_id", "sequence_id"),
    )

    sequence_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"), nullable=False
    )
    actor_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    client_record_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    operation_type: Mapped[str] = mapped_column(String(32), nullable=False)
    operation_data: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    server_updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
