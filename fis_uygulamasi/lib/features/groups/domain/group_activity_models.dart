enum GroupActivityType {
  expenseAdded,
  expenseUpdated,
  expenseDeleted,
  groupCreated,
  settlementRecorded,
  memberJoined,
  memberLeft,
  invitationAccepted,
}

enum GroupActivityBalanceEffect { receivable, payable, neutral }

/// Presentation-ready activity item matching the future group activity feed.
///
/// Money stays in minor units so replacing the demo source with an API-backed
/// repository does not change the UI contract.
class GroupActivityEntry {
  const GroupActivityEntry({
    required this.id,
    required this.type,
    required this.actorName,
    required this.actorAvatarId,
    required this.isCurrentUserActor,
    required this.subject,
    required this.groupName,
    required this.occurredAt,
    required this.balanceEffect,
    required this.amountInMinor,
    required this.currency,
  });

  final String id;
  final GroupActivityType type;
  final String actorName;
  final String? actorAvatarId;
  final bool isCurrentUserActor;
  final String subject;
  final String groupName;
  final DateTime occurredAt;
  final GroupActivityBalanceEffect balanceEffect;
  final int amountInMinor;
  final String? currency;
}
