import 'dart:convert';

import 'package:app_main/core/errors/user_facing_error.dart';
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

  test(
    'farklı Google client audience kullanıcıya teknik ayrıntı sızdırmaz',
    () {
      final token = _unsignedToken({
        'aud': 'android-client.apps.googleusercontent.com',
      });

      late AuthException exception;
      try {
        validateGoogleIdTokenAudience(
          token,
          expectedAudience: 'web-client.apps.googleusercontent.com',
        );
        fail('Audience eşleşmezken AuthException bekleniyordu.');
      } on AuthException catch (error) {
        exception = error;
      }

      final userMessage = userFacingErrorMessage(
        exception,
        fallbackMessage: 'fallback',
      );

      expect(
        userMessage,
        'Google girişi doğrulanamadı. Lütfen tekrar deneyin.',
      );
      expect(exception.code, 'google_token_verification_failed');
      expect(userMessage, isNot(contains('GOOGLE_SERVER_CLIENT_ID')));
      expect(userMessage, isNot(contains('GOOGLE_OAUTH_CLIENT_IDS')));
      expect(userMessage, isNot(contains('OAuth')));
      expect(userMessage, isNot(contains('Client ID')));
    },
  );

  test('okunamayan Google token kullanıcıya teknik ayrıntı sızdırmaz', () {
    expect(
      () => validateGoogleIdTokenAudience(
        'geçersiz-token',
        expectedAudience: 'web-client.apps.googleusercontent.com',
      ),
      throwsA(
        isA<AuthException>()
            .having(
              (error) => error.message,
              'message',
              'Google girişi doğrulanamadı. Lütfen tekrar deneyin.',
            )
            .having(
              (error) => error.message,
              'teknik ayrıntılar',
              allOf(
                isNot(contains('GOOGLE_SERVER_CLIENT_ID')),
                isNot(contains('GOOGLE_OAUTH_CLIENT_IDS')),
                isNot(contains('OAuth')),
                isNot(contains('Client ID')),
              ),
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
