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
