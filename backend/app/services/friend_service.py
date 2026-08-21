import uuid
from collections import defaultdict

from sqlalchemy.ext.asyncio import AsyncSession

from app.friend_schemas import FriendEntry
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository
from app.repositories.settlements import SettlementRepository
from app.repositories.users import UserRepository


class FriendService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.group_repository = GroupRepository(session)
        self.expense_repository = GroupExpenseRepository(session)
        self.settlement_repository = SettlementRepository(session)
        self.user_repository = UserRepository(session)

    async def list_friends(self, actor_user_id: uuid.UUID) -> list[FriendEntry]:
        direct_groups = await self.group_repository.list_direct_for_user(
            actor_user_id, include_archived=False
        )
        if not direct_groups:
            return []

        # ``list_for_user`` only returns non-direct groups; it is used below
        # purely to find normal groups shared with a given friend.
        groups = await self.group_repository.list_for_user(
            actor_user_id, include_archived=False
        )

        counterpart_by_direct_group: dict[uuid.UUID, uuid.UUID] = {}
        for group in direct_groups:
            counterpart = next(
                (
                    member.user_id
                    for member in group.members
                    if member.user_id != actor_user_id and member.left_at is None
                ),
                None,
            )
            if counterpart is None:  # pragma: no cover - database invariant guard
                continue
            counterpart_by_direct_group[group.id] = counterpart

        friend_user_ids = set(counterpart_by_direct_group.values())

        # Every friend is always reachable through their own direct group;
        # normal groups shared with that same person only add to the set.
        relevant_group_ids_by_friend: defaultdict[uuid.UUID, set[uuid.UUID]] = (
            defaultdict(set)
        )
        for direct_group_id, friend_id in counterpart_by_direct_group.items():
            relevant_group_ids_by_friend[friend_id].add(direct_group_id)

        shared_group_ids: defaultdict[uuid.UUID, list[uuid.UUID]] = defaultdict(list)
        for group in groups:
            if group.is_direct:
                continue
            active_member_ids = {
                member.user_id for member in group.members if member.left_at is None
            }
            if actor_user_id not in active_member_ids:
                continue
            for friend_id in sorted(friend_user_ids & active_member_ids, key=str):
                shared_group_ids[friend_id].append(group.id)
                relevant_group_ids_by_friend[friend_id].add(group.id)

        all_group_ids = {
            group_id
            for group_ids in relevant_group_ids_by_friend.values()
            for group_id in group_ids
        }
        expenses = await self.expense_repository.list_for_groups(list(all_group_ids))
        settlements = await self.settlement_repository.list_for_groups(
            list(all_group_ids)
        )

        expenses_by_group: defaultdict[uuid.UUID, list] = defaultdict(list)
        for expense in expenses:
            expenses_by_group[expense.group_id].append(expense)
        settlements_by_group: defaultdict[uuid.UUID, list] = defaultdict(list)
        for settlement in settlements:
            settlements_by_group[settlement.group_id].append(settlement)

        friend_users = {
            user.id: user
            for user in await self.user_repository.list_by_ids(friend_user_ids)
        }

        entries: list[FriendEntry] = []
        for direct_group in sorted(
            direct_groups, key=lambda group: (group.created_at, str(group.id))
        ):
            friend_id = counterpart_by_direct_group.get(direct_group.id)
            if friend_id is None:
                continue
            friend_user = friend_users.get(friend_id)

            net_amount_in_minor = 0
            for group_id in relevant_group_ids_by_friend[friend_id]:
                for expense in expenses_by_group.get(group_id, ()):
                    if expense.payer_user_id == actor_user_id:
                        net_amount_in_minor += next(
                            (
                                share.amount_in_minor
                                for share in expense.shares
                                if share.user_id == friend_id
                            ),
                            0,
                        )
                    elif expense.payer_user_id == friend_id:
                        net_amount_in_minor -= next(
                            (
                                share.amount_in_minor
                                for share in expense.shares
                                if share.user_id == actor_user_id
                            ),
                            0,
                        )
                for settlement in settlements_by_group.get(group_id, ()):
                    if (
                        settlement.from_user_id == actor_user_id
                        and settlement.to_user_id == friend_id
                    ):
                        net_amount_in_minor += settlement.amount_in_minor
                    elif (
                        settlement.from_user_id == friend_id
                        and settlement.to_user_id == actor_user_id
                    ):
                        net_amount_in_minor -= settlement.amount_in_minor

            entries.append(
                FriendEntry.build(
                    user_id=friend_id,
                    display_name=(
                        (friend_user.display_name if friend_user else None)
                        or "Silinmiş kullanıcı"
                    ),
                    avatar_id=friend_user.avatar_id if friend_user else None,
                    email=friend_user.email if friend_user else "",
                    direct_group_id=direct_group.id,
                    net_amount_in_minor=net_amount_in_minor,
                    currency=direct_group.currency,
                    shared_group_ids=sorted(
                        shared_group_ids.get(friend_id, []), key=str
                    ),
                )
            )
        return entries
