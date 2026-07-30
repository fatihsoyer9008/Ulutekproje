import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const email = 'user@example.com';
  const password = 'Strong-password-123';

  test('kayıt sonrası e-posta doğrulama durumuna geçer', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthSessionController(repository);

    final registered = await controller.register(
      email: email,
      password: password,
    );

    expect(registered, isTrue);
    expect(
      controller.state.status,
      AuthStatus.emailVerificationRequired,
    );
    expect(controller.state.pendingEmail, email);
  });

  test('doğrulanmamış login doğrulama ekranı stateini üretir', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthSessionController(repository);

    final authenticated = await controller.login(email, password);

    expect(authenticated, isFalse);
    expect(
      controller.state.status,
      AuthStatus.emailVerificationRequired,
    );
  });

  test('token doğrulandıktan sonra bekleyen oturumu açar', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthSessionController(repository);
    await controller.register(email: email, password: password);

    final authenticated = await controller.verifyEmailToken('v' * 32);

    expect(authenticated, isTrue);
    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.isEmailVerified, isTrue);
  });
}

class _FakeAuthRepository implements AuthRepositoryBase {
  bool verified = false;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    if (!verified) {
      throw const AuthException(
        'E-posta adresi henüz doğrulanmadı.',
        code: 'email_not_verified',
      );
    }
    return AuthUser(
      id: 'user-id',
      email: email,
      isEmailVerified: true,
    );
  }

  @override
  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  }) async => 'Doğrulama bağlantısı gönderildi.';

  @override
  Future<String> verifyEmail(String token) async {
    verified = true;
    return 'E-posta adresiniz doğrulandı.';
  }

  @override
  Future<String> resendVerification(String email) async =>
      'Doğrulama bağlantısı yeniden gönderildi.';

  @override
  Future<void> deleteAccount({String? currentPassword}) async {}

  @override
  Future<String> forgotPassword(String email) async => 'Gönderildi.';

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> silentRefresh() async => null;

  @override
  Future<AuthUser> signInWithGoogle() {
    throw UnimplementedError();
  }
}
