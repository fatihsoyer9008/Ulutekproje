import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Index, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class UserStatus(str, enum.Enum):
    active = "active"
    suspended = "suspended"
    deletion_pending = "deletion_pending"


class User(Base):
    __tablename__ = "users"
    __table_args__ = (Index("ix_users_email", "email", unique=True),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String(512))
    display_name: Mapped[str | None] = mapped_column(String(120))
    is_email_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    status: Mapped[UserStatus] = mapped_column(
        Enum(UserStatus, name="user_status", native_enum=False),
        nullable=False,
        default=UserStatus.active,
        server_default=UserStatus.active.value,
    )
    auth_version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        server_default="1",
    )
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    assistant_consent_version: Mapped[str | None] = mapped_column(String(64))
    assistant_consent_granted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True)
    )
    assistant_consent_revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True)
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

    oauth_accounts = relationship(
        "OAuthAccount",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    refresh_sessions = relationship(
        "RefreshSession",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
        foreign_keys="RefreshSession.user_id",
    )
    one_time_tokens = relationship(
        "OneTimeToken",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    cloud_transactions = relationship(
        "CloudTransaction",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    cloud_receipts = relationship(
        "CloudReceipt",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    created_groups = relationship(
        "Group",
        back_populates="creator",
        passive_deletes=True,
        foreign_keys="Group.created_by",
    )
    group_memberships = relationship(
        "GroupMember",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
