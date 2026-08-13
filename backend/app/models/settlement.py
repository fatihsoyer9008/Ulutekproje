import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Settlement(Base):
    __tablename__ = "settlements"
    __table_args__ = (
        CheckConstraint(
            "amount_in_minor > 0",
            name="ck_settlements_amount_positive",
        ),
        CheckConstraint(
            "from_user_id <> to_user_id",
            name="ck_settlements_distinct_users",
        ),
        CheckConstraint(
            "currency = upper(currency) AND length(currency) = 3",
            name="ck_settlements_currency_format",
        ),
        Index(
            "ix_settlements_group_settled_at_id",
            "group_id",
            "settled_at",
            "id",
        ),
        Index("ix_settlements_from_user_id", "from_user_id"),
        Index("ix_settlements_to_user_id", "to_user_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,
        default=uuid.uuid4,
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"),
        nullable=False,
    )

    # Historical UUIDs deliberately have no users.id foreign key.
    from_user_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    to_user_id: Mapped[uuid.UUID] = mapped_column(nullable=False)

    amount_in_minor: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
    )
    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
    )
    settled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    group = relationship("Group")


class SettlementIdempotencyRecord(Base):
    __tablename__ = "settlement_idempotency_records"
    __table_args__ = (
        UniqueConstraint(
            "group_id",
            "actor_user_id",
            "idempotency_key_hash",
            name="uq_settlement_idempotency_scope_key",
        ),
        Index(
            "ix_settlement_idempotency_actor_user_id",
            "actor_user_id",
        ),
        Index(
            "ix_settlement_idempotency_settlement_id",
            "settlement_id",
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
    settlement_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("settlements.id", ondelete="CASCADE"),
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
