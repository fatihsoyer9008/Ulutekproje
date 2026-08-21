import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr

from app.friend_schemas import FriendEntry


class FriendInvitationCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr


class FriendInvitationRequestReceived(BaseModel):
    status: Literal["request_received"] = "request_received"


class FriendInvitationAcceptResponse(BaseModel):
    friend: FriendEntry


class PendingFriendInvitation(BaseModel):
    id: uuid.UUID
    inviter_display_name: str
    created_at: datetime
    expires_at: datetime


class PendingFriendInvitationsResponse(BaseModel):
    invitations: list[PendingFriendInvitation]
