import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('canceled hatası OAuth yapılandırma yönlendirmesi içerir', () {
    final message = googleSignInErrorMessage(
      GoogleSignInExceptionCode.canceled,
    );

    expect(message, contains('SHA-1/SHA-256'));
    expect(message, isNot(contains('canceled')));
  });

  test('istemci yapılandırma hatası kullanıcı dostu metne dönüşür', () {
    final message = googleSignInErrorMessage(
      GoogleSignInExceptionCode.clientConfigurationError,
    );

    expect(message, contains('Google giriş yapılandırması geçersiz'));
  });
}
