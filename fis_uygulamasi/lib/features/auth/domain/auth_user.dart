class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.isEmailVerified,
    this.displayName,
    this.avatarId,
  });

  final String id;
  final String email;
  final String? displayName;
  final bool isEmailVerified;
  final String? avatarId;

  AuthUser copyWith({String? avatarId}) => AuthUser(
    id: id,
    email: email,
    isEmailVerified: isEmailVerified,
    displayName: displayName,
    avatarId: avatarId ?? this.avatarId,
  );

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final verified = json['is_email_verified'];
    if (id is! String || email is! String || verified is! bool) {
      throw const FormatException('Geçersiz kullanıcı cevabı.');
    }
    return AuthUser(
      id: id,
      email: email,
      displayName: json['display_name'] as String?,
      isEmailVerified: verified,
      avatarId: json['avatar_id'] as String?,
    );
  }
}
