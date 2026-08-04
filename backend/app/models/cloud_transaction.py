import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
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


class CloudTransaction(Base):
    __tablename__ = "cloud_transactions"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "client_record_id",
            name="uq_cloud_transaction_user_client_record",
        ),
        Index(
            "ix_cloud_transactions_user_date",
            "user_id",
            "transaction_date",
        ),
        Index(
            "ix_cloud_transactions_user_updated_id",
            "user_id",
            "updated_at",
            "id",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    client_record_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    installation_id_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    transaction_type: Mapped[str] = mapped_column(String(32), nullable=False)
    amount_in_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    category: Mapped[str] = mapped_column(String(64), nullable=False)
    transaction_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    merchant_name: Mapped[str | None] = mapped_column(String(255))
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    raw_ocr_text: Mapped[str | None] = mapped_column(Text)
    note: Mapped[str | None] = mapped_column(String(1000))
    client_created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    client_updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user = relationship("User", back_populates="cloud_transactions")
