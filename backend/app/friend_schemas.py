import uuid

from pydantic import BaseModel


class FriendEntry(BaseModel):
    user_id: uuid.UUID
    display_name: str
    avatar_id: str | None
    direct_group_id: uuid.UUID
    net_amount_in_minor: int
    currency: str
    status: str
    shared_group_ids: list[uuid.UUID]

    @classmethod
    def build(
        cls,
        *,
        user_id: uuid.UUID,
        display_name: str,
        avatar_id: str | None,
        direct_group_id: uuid.UUID,
        net_amount_in_minor: int,
        currency: str,
        shared_group_ids: list[uuid.UUID],
    ) -> "FriendEntry":
        if net_amount_in_minor > 0:
            status = "you_are_owed"
        elif net_amount_in_minor < 0:
            status = "you_owe"
        else:
            status = "settled_up"
        return cls(
            user_id=user_id,
            display_name=display_name,
            avatar_id=avatar_id,
            direct_group_id=direct_group_id,
            net_amount_in_minor=net_amount_in_minor,
            currency=currency,
            status=status,
            shared_group_ids=shared_group_ids,
        )


class FriendsResponse(BaseModel):
    friends: list[FriendEntry]
