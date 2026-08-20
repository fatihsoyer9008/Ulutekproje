import enum
import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, Enum, ForeignKey, Index, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ActivityType(str, enum.Enum):
    expense_created = "expense_created"
    settlement_created = "settlement_created"
    member_joined = "member_joined"


class ActivityLog(Base):
    """Append-only feed of human-readable, group-scoped events.

    Written inside the same transaction as the action it describes (see
    ActivityLogRepository.record), never updated or deleted afterwards.
    """

    __tablename__ = "activity_log"
    __table_args__ = (
        Index(
            "ix_activity_log_group_created",
            "group_id",
            "created_at",
            "id",
        ),
        Index("ix_activity_log_actor_user_id", "actor_user_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"),
        nullable=False,
    )
    # Historical UUID intentionally outlives the User row (matches
    # GroupExpense.payer_user_id / Settlement.from_user_id conventions).
    actor_user_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    type: Mapped[ActivityType] = mapped_column(
        Enum(
            ActivityType,
            name="activity_log_type",
            native_enum=False,
            create_constraint=False,
            validate_strings=True,
            length=32,
        ),
        nullable=False,
    )
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    group = relationship("Group")
