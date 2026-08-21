import uuid
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.activity_log import ActivityType
from app.models.settlement import Settlement
from app.models.user import User
from app.repositories.activity_log import ActivityLogRepository
from app.repositories.groups import GroupRepository
from app.repositories.settlements import SettlementRepository

_MAX_BIGINT = 9_223_372_036_854_775_807


class SettlementValidationError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class SettlementService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = SettlementRepository(session)
        self.activity_log = ActivityLogRepository(session)

    async def create(
        self,
        *,
        group_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        from_user_id: uuid.UUID,
        to_user_id: uuid.UUID,
        amount_in_minor: int,
        currency: str,
        settled_at: datetime,
        note: str | None,
    ) -> Settlement:
        group = await GroupRepository(self.session).get_by_id(
            group_id,
            include_members=True,
            for_update=True,
        )
        if group is None:
            raise SettlementValidationError("group_not_found")
        if group.archived_at is not None:
            raise SettlementValidationError("group_forbidden")

        if from_user_id != actor_user_id:
            raise SettlementValidationError("sender_must_match_actor")
        if from_user_id == to_user_id:
            raise SettlementValidationError("self_settlement")

        if (
            type(amount_in_minor) is not int
            or amount_in_minor <= 0
            or amount_in_minor > _MAX_BIGINT
        ):
            raise SettlementValidationError("invalid_amount")

        normalized_currency = currency.strip().upper()
        if normalized_currency != group.currency.upper():
            raise SettlementValidationError("currency_mismatch")

        if settled_at.tzinfo is None or settled_at.utcoffset() is None:
            raise SettlementValidationError("invalid_settled_at")

        required_member_ids = {from_user_id, to_user_id}
        active_member_ids = {
            member.user_id for member in group.members if member.left_at is None
        }
        if required_member_ids - active_member_ids:
            raise SettlementValidationError("member_not_found")

        settlement = await self.repository.create(
            group_id=group_id,
            from_user_id=from_user_id,
            to_user_id=to_user_id,
            amount_in_minor=amount_in_minor,
            currency=normalized_currency,
            settled_at=settled_at,
            note=note,
        )
        actor = await self.session.get(User, actor_user_id)
        self.activity_log.record(
            group_id=group_id,
            actor_user_id=actor_user_id,
            type=ActivityType.settlement_created,
            payload={
                "actor_display_name": (
                    (actor.display_name or actor.email) if actor is not None else None
                )
                or "Silinmiş kullanıcı",
                "settlement_id": str(settlement.id),
                "from_user_id": str(from_user_id),
                "to_user_id": str(to_user_id),
                "amount_in_minor": amount_in_minor,
                "currency": normalized_currency,
            },
        )
        return settlement
