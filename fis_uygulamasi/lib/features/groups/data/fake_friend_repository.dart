import '../domain/friend_models.dart';
import 'demo_friend_seed.dart';
import 'friend_repository.dart';

/// In-memory stand-in used for `GROUP_MOCK_MODE` demos and widget tests.
/// Invitations cannot really be delivered/accepted by e-mail without a
/// server, so [createInvitation] is a no-op and [acceptInvitation] (token
/// based) is unsupported; [pendingInvitations] and [acceptInvitationById]
/// simulate the in-app "received invitations" list instead.
class FakeFriendRepository implements FriendRepository {
  FakeFriendRepository({
    List<FriendSummary>? friends,
    List<PendingFriendInvitation>? pendingInvitations,
  }) : _friends = List<FriendSummary>.of(friends ?? createDemoFriendSeed()),
       _pendingInvitations = List<PendingFriendInvitation>.of(
         pendingInvitations ?? const [],
       );

  final List<FriendSummary> _friends;
  final List<PendingFriendInvitation> _pendingInvitations;

  @override
  Future<List<FriendSummary>> listFriends() async =>
      List<FriendSummary>.unmodifiable(_friends);

  @override
  Future<void> createInvitation({required String email}) async {}

  @override
  Future<FriendSummary> acceptInvitation(String token) {
    throw UnimplementedError(
      'Arkadaşlık daveti kabul etme demo modda desteklenmiyor.',
    );
  }

  @override
  Future<List<PendingFriendInvitation>> listPendingInvitations() async =>
      List<PendingFriendInvitation>.unmodifiable(_pendingInvitations);

  @override
  Future<FriendSummary> acceptInvitationById(String invitationId) async {
    _pendingInvitations.removeWhere(
      (invitation) => invitation.id == invitationId,
    );
    final accepted = FriendSummary(
      userId: 'user-$invitationId',
      displayName: 'Yeni Arkadaş',
      avatarId: null,
      email: 'yeni.arkadas@example.com',
      directGroupId: 'group-$invitationId',
      netAmountInMinor: 0,
      currency: 'TRY',
      status: 'settled_up',
      sharedGroupIds: const [],
    );
    _friends.add(accepted);
    return accepted;
  }
}
