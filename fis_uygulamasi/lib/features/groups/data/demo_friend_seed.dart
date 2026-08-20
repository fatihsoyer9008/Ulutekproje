import '../domain/friend_models.dart';

/// Static mock data used until the Friends tab is wired to
/// `GET /api/v1/friends`. See `demo_group_seed.dart` for the same pattern
/// applied to groups.
List<FriendSummary> createDemoFriendSeed() => const [
  FriendSummary(
    userId: '00000000-0000-4000-8000-000000000010',
    displayName: 'Ege Başaran',
    avatarId: 'man',
    directGroupId: '20000000-0000-4000-8000-000000000001',
    netAmountInMinor: -27522,
    currency: 'TRY',
  ),
  FriendSummary(
    userId: '00000000-0000-4000-8000-000000000011',
    displayName: 'Elifnur Kaya',
    avatarId: 'woman',
    directGroupId: '20000000-0000-4000-8000-000000000002',
    netAmountInMinor: 12000,
    currency: 'TRY',
  ),
  FriendSummary(
    userId: '00000000-0000-4000-8000-000000000012',
    displayName: 'Mine Akçakala',
    avatarId: 'bearded_man',
    directGroupId: '20000000-0000-4000-8000-000000000003',
    netAmountInMinor: 0,
    currency: 'TRY',
  ),
];
