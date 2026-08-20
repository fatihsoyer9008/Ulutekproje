/// UI-only summary of a friend (a direct 1:1 group's counterpart), matching
/// the shape of the future `GET /api/v1/friends` response. This is a
/// presentation-layer model for the Friends tab design pass; it is not yet
/// wired to a repository/provider.
class FriendSummary {
  const FriendSummary({
    required this.userId,
    required this.displayName,
    required this.avatarId,
    required this.directGroupId,
    required this.netAmountInMinor,
    required this.currency,
  });

  final String userId;
  final String displayName;
  final String? avatarId;
  final String directGroupId;

  /// Positive: the current user is owed. Negative: the current user owes.
  final int netAmountInMinor;
  final String currency;
}
