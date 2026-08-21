import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class FriendInvitation(Base):
    __tablename__ = "friend_invitations"
    __table_args__ = (
        CheckConstraint(
            "expires_at > created_at",
            name="ck_friend_invitations_expiry_after_creation",
        ),
        CheckConstraint(
            "accepted_at IS NOT NULL OR accepted_by_user_id IS NULL",
            name="ck_friend_invitations_acceptance_state",
        ),
        Index("ix_friend_invitations_token_hash", "token_hash", unique=True),
        Index(
            "ix_friend_invitations_email_created_at",
            "invited_email",
            "created_at",
        ),
        Index("ix_friend_invitations_expires_at", "expires_at"),
        Index("ix_friend_invitations_invited_by_user_id", "invited_by_user_id"),
        Index("ix_friend_invitations_accepted_by_user_id", "accepted_by_user_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    invited_email: Mapped[str] = mapped_column(String(320), nullable=False)
    invited_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    accepted_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
