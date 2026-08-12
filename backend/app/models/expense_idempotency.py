import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class GroupExpenseIdempotencyRecord(Base):
    __tablename__ = "group_expense_idempotency_records"
    __table_args__ = (
        UniqueConstraint(
            "group_id",
            "actor_user_id",
            "idempotency_key_hash",
            name="uq_group_expense_idempotency_scope_key",
        ),
        Index(
            "ix_group_expense_idempotency_actor_user_id",
            "actor_user_id",
        ),
        Index(
            "ix_group_expense_idempotency_expense_id",
            "expense_id",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,
        default=uuid.uuid4,
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"),
        nullable=False,
    )
    actor_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    expense_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("group_expenses.id", ondelete="CASCADE"),
        nullable=True,
    )
    idempotency_key_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
    )
    request_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
