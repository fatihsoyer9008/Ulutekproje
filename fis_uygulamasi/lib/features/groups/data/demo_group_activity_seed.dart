import '../domain/group_activity_models.dart';

/// Runtime demo data for the Activity UI until the activity feed endpoint is
/// available. The page accepts injected entries, so an API provider can
/// replace this source without changing the widgets.
List<GroupActivityEntry> createDemoGroupActivitySeed({DateTime? now}) {
  final reference = now ?? DateTime.now();

  return <GroupActivityEntry>[
    GroupActivityEntry(
      id: 'activity-electricity',
      type: GroupActivityType.expenseAdded,
      actorName: 'You',
      actorAvatarId: 'woman',
      isCurrentUserActor: true,
      subject: 'Elektrik',
      groupName: 'Bursa',
      occurredAt: reference.subtract(const Duration(days: 2, hours: 3)),
      balanceEffect: GroupActivityBalanceEffect.receivable,
      amountInMinor: 15350,
      currency: 'TRY',
    ),
    GroupActivityEntry(
      id: 'activity-natural-gas',
      type: GroupActivityType.expenseAdded,
      actorName: 'Ege B.',
      actorAvatarId: 'man',
      isCurrentUserActor: false,
      subject: 'Doğalgaz',
      groupName: 'Bursa',
      occurredAt: reference.subtract(const Duration(days: 5, hours: 1)),
      balanceEffect: GroupActivityBalanceEffect.payable,
      amountInMinor: 4000,
      currency: 'TRY',
    ),
    GroupActivityEntry(
      id: 'activity-superonline',
      type: GroupActivityType.expenseAdded,
      actorName: 'Ege B.',
      actorAvatarId: 'man',
      isCurrentUserActor: false,
      subject: 'Superonline',
      groupName: 'Bursa',
      occurredAt: reference.subtract(const Duration(days: 7, hours: 4)),
      balanceEffect: GroupActivityBalanceEffect.payable,
      amountInMinor: 35000,
      currency: 'TRY',
    ),
    GroupActivityEntry(
      id: 'activity-water',
      type: GroupActivityType.expenseAdded,
      actorName: 'Ege B.',
      actorAvatarId: 'man',
      isCurrentUserActor: false,
      subject: 'Su faturası',
      groupName: 'Bursa',
      occurredAt: reference.subtract(const Duration(days: 7, hours: 7)),
      balanceEffect: GroupActivityBalanceEffect.payable,
      amountInMinor: 26000,
      currency: 'TRY',
    ),
    GroupActivityEntry(
      id: 'activity-merava',
      type: GroupActivityType.expenseAdded,
      actorName: 'You',
      actorAvatarId: 'woman',
      isCurrentUserActor: true,
      subject: 'Merava',
      groupName: 'Proje',
      occurredAt: reference.subtract(const Duration(days: 30, hours: 2)),
      balanceEffect: GroupActivityBalanceEffect.neutral,
      amountInMinor: 0,
      currency: 'TRY',
    ),
    GroupActivityEntry(
      id: 'activity-group-created',
      type: GroupActivityType.groupCreated,
      actorName: 'You',
      actorAvatarId: 'woman',
      isCurrentUserActor: true,
      subject: 'Proje',
      groupName: 'Proje',
      occurredAt: reference.subtract(const Duration(days: 31, hours: 3)),
      balanceEffect: GroupActivityBalanceEffect.neutral,
      amountInMinor: 0,
      currency: 'TRY',
    ),
  ];
}
