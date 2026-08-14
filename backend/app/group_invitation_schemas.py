from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr

from app.models.group import GroupRole


class GroupInvitationCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr
    role: GroupRole = GroupRole.member


class GroupInvitationRequestReceived(BaseModel):
    status: Literal["request_received"] = "request_received"
