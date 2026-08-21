import '../domain/friend_models.dart';
import 'demo_friend_seed.dart';
import 'friend_repository.dart';

/// In-memory stand-in used for `GROUP_MOCK_MODE` demos. Invitations cannot
/// really be delivered/accepted without a server, so [createInvitation] is a
/// no-op and [acceptInvitation] is unsupported.
class FakeFriendRepository implements FriendRepository {
  FakeFriendRepository({List<FriendSummary>? friends})
    : _friends = List<FriendSummary>.of(friends ?? createDemoFriendSeed());

  final List<FriendSummary> _friends;

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
}
