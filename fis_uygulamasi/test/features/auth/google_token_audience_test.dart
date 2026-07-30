import 'dart:convert';

import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google ID token web client audience eşleşmesini kabul eder', () {
    final token = _unsignedToken({
      'aud': 'web-client.apps.googleusercontent.com',
    });

    expect(
      () => validateGoogleIdTokenAudience(
        token,
        expectedAudience: 'web-client.apps.googleusercontent.com',
      ),
      returnsNormally,
    );
  });

  test('farklı Google client audience için açıklayıcı hata verir', () {
    final token = _unsignedToken({
      'aud': 'android-client.apps.googleusercontent.com',
    });

    expect(
      () => validateGoogleIdTokenAudience(
        token,
        expectedAudience: 'web-client.apps.googleusercontent.com',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('Client ID eşleşmiyor'),
        ),
      ),
    );
  });
}

String _unsignedToken(Map<String, dynamic> payload) {
  String encode(Map<String, dynamic> value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode(payload)}.signature';
}
