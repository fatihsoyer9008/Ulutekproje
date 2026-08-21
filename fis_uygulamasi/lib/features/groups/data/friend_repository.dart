import '../domain/friend_models.dart';

abstract interface class FriendRepository {
  Future<List<FriendSummary>> listFriends();

  Future<void> createInvitation({required String email});

  Future<FriendSummary> acceptInvitation(String token);

  Future<List<PendingFriendInvitation>> listPendingInvitations();

  Future<FriendSummary> acceptInvitationById(String invitationId);
}
