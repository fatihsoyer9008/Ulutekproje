import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr

from app.models.group import GroupRole


class GroupInvitationCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr
    role: GroupRole = GroupRole.member


class GroupInvitationRequestReceived(BaseModel):
    status: Literal["request_received"] = "request_received"


class PendingGroupInvitation(BaseModel):
    id: uuid.UUID
    group_id: uuid.UUID
    group_name: str
    role: GroupRole
    inviter_display_name: str
    created_at: datetime
    expires_at: datetime


class PendingGroupInvitationsResponse(BaseModel):
    invitations: list[PendingGroupInvitation]
