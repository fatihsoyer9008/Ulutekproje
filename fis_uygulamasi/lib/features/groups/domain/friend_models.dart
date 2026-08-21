/// A friend (the counterpart of one of the current user's `is_direct`
/// groups), matching `GET /api/v1/friends` and the `friend` field of
/// `POST /api/v1/friend-invitations/{token}/accept`.
class FriendSummary {
  const FriendSummary({
    required this.userId,
    required this.displayName,
    required this.avatarId,
    required this.email,
    required this.directGroupId,
    required this.netAmountInMinor,
    required this.currency,
    required this.status,
    required this.sharedGroupIds,
  });

  factory FriendSummary.fromJson(Map<String, Object?> json) => FriendSummary(
    userId: json['user_id']! as String,
    displayName: json['display_name']! as String,
    avatarId: json['avatar_id'] as String?,
    email: json['email']! as String,
    directGroupId: json['direct_group_id']! as String,
    netAmountInMinor: json['net_amount_in_minor']! as int,
    currency: json['currency']! as String,
    status: json['status']! as String,
    sharedGroupIds: (json['shared_group_ids']! as List<Object?>).cast<String>(),
  );

  final String userId;
  final String displayName;
  final String? avatarId;
  final String email;
  final String directGroupId;

  /// Positive: the current user is owed. Negative: the current user owes.
  final int netAmountInMinor;
  final String currency;

  /// One of `you_owe`, `you_are_owed`, `settled_up`.
  final String status;
  final List<String> sharedGroupIds;
}

/// A friend invitation addressed to the current user's verified e-mail,
/// still waiting to be accepted. Matches `GET /api/v1/friends/invitations/pending`.
class PendingFriendInvitation {
  const PendingFriendInvitation({
    required this.id,
    required this.inviterDisplayName,
    required this.createdAt,
    required this.expiresAt,
  });

  factory PendingFriendInvitation.fromJson(Map<String, Object?> json) =>
      PendingFriendInvitation(
        id: json['id']! as String,
        inviterDisplayName: json['inviter_display_name']! as String,
        createdAt: json['created_at']! as String,
        expiresAt: json['expires_at']! as String,
      );

  final String id;
  final String inviterDisplayName;
  final String createdAt;
  final String expiresAt;
}

class PendingFriendInvitationsResponse {
  const PendingFriendInvitationsResponse({required this.invitations});

  factory PendingFriendInvitationsResponse.fromJson(
    Map<String, Object?> json,
  ) => PendingFriendInvitationsResponse(
    invitations: (json['invitations']! as List<Object?>)
        .map(
          (item) => PendingFriendInvitation.fromJson(
            item! as Map<String, Object?>,
          ),
        )
        .toList(growable: false),
  );

  final List<PendingFriendInvitation> invitations;
}

class FriendsResponse {
  const FriendsResponse({required this.friends});

  factory FriendsResponse.fromJson(Map<String, Object?> json) =>
      FriendsResponse(
        friends: (json['friends']! as List<Object?>)
            .map(
              (item) => FriendSummary.fromJson(item! as Map<String, Object?>),
            )
            .toList(growable: false),
      );

  final List<FriendSummary> friends;
}
