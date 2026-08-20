import uuid
from datetime import UTC, datetime

from pydantic import BaseModel, field_serializer

from app.models.activity_log import ActivityLog, ActivityType


class ActivityActorResponse(BaseModel):
    user_id: uuid.UUID
    display_name: str


class ActivityGroupResponse(BaseModel):
    id: uuid.UUID
    name: str
    is_direct: bool


class ActivityExpenseDetails(BaseModel):
    expense_id: uuid.UUID
    title: str
    total_amount_in_minor: int
    currency: str


class ActivitySettlementDetails(BaseModel):
    settlement_id: uuid.UUID
    from_user_id: uuid.UUID
    to_user_id: uuid.UUID
    amount_in_minor: int
    currency: str


class ActivityMemberDetails(BaseModel):
    user_id: uuid.UUID
    display_name: str


class ActivityImpact(BaseModel):
    status: str
    amount_in_minor: int


class ActivityItemResponse(BaseModel):
    id: uuid.UUID
    type: ActivityType
    actor: ActivityActorResponse
    group: ActivityGroupResponse
    expense_details: ActivityExpenseDetails | None = None
    settlement_details: ActivitySettlementDetails | None = None
    member_details: ActivityMemberDetails | None = None
    impact: ActivityImpact | None = None
    created_at: datetime

    @field_serializer("created_at", when_used="json")
    def serialize_created_at(self, value: datetime) -> str:
        if value.tzinfo is None:
            value = value.replace(tzinfo=UTC)
        return value.astimezone(UTC).isoformat().replace("+00:00", "Z")

    @classmethod
    def from_model(
        cls,
        activity: ActivityLog,
        *,
        viewer_id: uuid.UUID,
    ) -> "ActivityItemResponse":
        payload = activity.payload_json
        group = ActivityGroupResponse(
            id=activity.group_id,
            name=activity.group.name if activity.group is not None else "",
            is_direct=activity.group.is_direct if activity.group is not None else False,
        )
        actor = ActivityActorResponse(
            user_id=activity.actor_user_id,
            display_name=payload.get("actor_display_name") or "Silinmiş kullanıcı",
        )

        expense_details: ActivityExpenseDetails | None = None
        settlement_details: ActivitySettlementDetails | None = None
        member_details: ActivityMemberDetails | None = None
        impact: ActivityImpact | None = None

        if activity.type is ActivityType.expense_created:
            expense_details = ActivityExpenseDetails(
                expense_id=uuid.UUID(payload["expense_id"]),
                title=payload["title"],
                total_amount_in_minor=payload["total_amount_in_minor"],
                currency=payload["currency"],
            )
            shares: dict[str, int] = payload.get("shares", {})
            viewer_share = shares.get(str(viewer_id))
            payer_user_id = payload["payer_user_id"]
            if str(viewer_id) == payer_user_id:
                viewer_owed_back = payload["total_amount_in_minor"] - (
                    viewer_share or 0
                )
                if viewer_owed_back != 0:
                    impact = ActivityImpact(
                        status="you_are_owed",
                        amount_in_minor=viewer_owed_back,
                    )
            elif viewer_share is not None and viewer_share > 0:
                impact = ActivityImpact(status="you_owe", amount_in_minor=viewer_share)
        elif activity.type is ActivityType.settlement_created:
            settlement_details = ActivitySettlementDetails(
                settlement_id=uuid.UUID(payload["settlement_id"]),
                from_user_id=uuid.UUID(payload["from_user_id"]),
                to_user_id=uuid.UUID(payload["to_user_id"]),
                amount_in_minor=payload["amount_in_minor"],
                currency=payload["currency"],
            )
            if str(viewer_id) == payload["to_user_id"]:
                impact = ActivityImpact(
                    status="you_get_back",
                    amount_in_minor=payload["amount_in_minor"],
                )
        elif activity.type is ActivityType.member_joined:
            member_details = ActivityMemberDetails(
                user_id=uuid.UUID(payload["member_user_id"]),
                display_name=payload["member_display_name"],
            )

        return cls(
            id=activity.id,
            type=activity.type,
            actor=actor,
            group=group,
            expense_details=expense_details,
            settlement_details=settlement_details,
            member_details=member_details,
            impact=impact,
            created_at=activity.created_at,
        )


class ActivityFeedResponse(BaseModel):
    items: list[ActivityItemResponse]
    next_cursor: str | None
