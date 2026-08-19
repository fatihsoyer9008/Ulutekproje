import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('iptal hatası teknik OAuth ayrıntısı içermez', () {
    final message = googleSignInErrorMessage(
      GoogleSignInExceptionCode.canceled,
    );

    expect(message, 'Google giriş işlemi iptal edildi.');
    expect(message, isNot(contains('SHA-1/SHA-256')));
    expect(message, isNot(contains('canceled')));
  });

  test('istemci yapılandırma hatası kullanıcı dostu metne dönüşür', () {
    final message = googleSignInErrorMessage(
      GoogleSignInExceptionCode.clientConfigurationError,
    );

    expect(message, contains('Google ile giriş şu anda kullanılamıyor'));
    expect(message, isNot(contains('GOOGLE_SERVER_CLIENT_ID')));
  });
}
