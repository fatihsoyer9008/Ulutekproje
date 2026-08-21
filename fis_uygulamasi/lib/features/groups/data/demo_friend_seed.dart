import '../domain/friend_models.dart';

/// Static mock data used for `GROUP_MOCK_MODE` demos, until the underlying
/// fake repository grows real invite/create support. See
/// `demo_group_seed.dart` for the same pattern applied to groups.
List<FriendSummary> createDemoFriendSeed() => const [
  FriendSummary(
    userId: '00000000-0000-4000-8000-000000000010',
    displayName: 'Ege Başaran',
    avatarId: 'man',
    email: 'ege.basaran@example.com',
    directGroupId: '20000000-0000-4000-8000-000000000001',
    netAmountInMinor: -27522,
    currency: 'TRY',
    status: 'you_owe',
    sharedGroupIds: [],
  ),
  FriendSummary(
    userId: '00000000-0000-4000-8000-000000000011',
    displayName: 'Elifnur Kaya',
    avatarId: 'woman',
    email: 'elifnur.kaya@example.com',
    directGroupId: '20000000-0000-4000-8000-000000000002',
    netAmountInMinor: 12000,
    currency: 'TRY',
    status: 'you_are_owed',
    sharedGroupIds: [],
  ),
  FriendSummary(
    userId: '00000000-0000-4000-8000-000000000012',
    displayName: 'Mine Akçakala',
    avatarId: 'bearded_man',
    email: 'mine.akcakala@example.com',
    directGroupId: '20000000-0000-4000-8000-000000000003',
    netAmountInMinor: 0,
    currency: 'TRY',
    status: 'settled_up',
    sharedGroupIds: [],
  ),
];
