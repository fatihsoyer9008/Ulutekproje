import base64
import binascii
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.activity_log import ActivityLog, ActivityType
from app.models.group import Group, GroupMember


class InvalidActivityCursor(ValueError):
    pass


def encode_activity_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(str(offset).encode("ascii")).decode("ascii")


def decode_activity_cursor(cursor: str) -> int:
    try:
        offset = int(base64.urlsafe_b64decode(cursor.encode("ascii")).decode("ascii"))
    except (binascii.Error, UnicodeDecodeError, ValueError) as error:
        raise InvalidActivityCursor("invalid_cursor") from error
    if offset < 0:
        raise InvalidActivityCursor("invalid_cursor")
    return offset


class ActivityLogRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    def record(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        type: ActivityType,
        payload: dict,
    ) -> ActivityLog:
        """Adds an ActivityLog row to the current session without flushing or
        committing — callers write this in the same transaction as the
        action it describes, so it either lands with that action or not at
        all.
        """
        entry = ActivityLog(
            group_id=group_id,
            actor_user_id=actor_user_id,
            type=type,
            payload_json=payload,
        )
        self.session.add(entry)
        return entry

    async def list_for_user(
        self,
        user_id: uuid.UUID,
        *,
        limit: int,
        offset: int = 0,
    ) -> list[ActivityLog]:
        statement = (
            select(ActivityLog)
            .join(Group, Group.id == ActivityLog.group_id)
            .join(GroupMember, GroupMember.group_id == Group.id)
            .where(
                GroupMember.user_id == user_id,
                GroupMember.left_at.is_(None),
            )
            .options(selectinload(ActivityLog.group))
            .order_by(ActivityLog.created_at.desc(), ActivityLog.id.desc())
            .offset(offset)
            .limit(limit)
        )
        return list((await self.session.scalars(statement)).unique().all())
