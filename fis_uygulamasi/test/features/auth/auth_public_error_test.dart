import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sunucunun teknik hata metnini kullanıcıya taşımaz', () async {
    final apiClient = _client(
      (_) => _jsonResponse({
        'detail':
            'SQLSTATE 42P01: relation auth_users does not exist at 10.0.0.8',
      }, statusCode: 500),
    );
    addTearDown(apiClient.close);
    final repository = AuthRepository(apiClient: apiClient);

    await expectLater(
      repository.login(email: 'user@example.com', password: 'secret'),
      throwsA(
        isA<AuthException>()
            .having((error) => error.message, 'message', contains('Servis'))
            .having(
              (error) => error.message,
              'does not expose SQL details',
              isNot(contains('SQLSTATE')),
            )
            .having(
              (error) => error.message,
              'does not expose internal address',
              isNot(contains('10.0.0.8')),
            ),
      ),
    );
  });

  test('Pydantic doğrulama ayrıntısını kısa Türkçe mesaja çevirir', () async {
    final apiClient = _client(
      (_) => _jsonResponse({
        'detail': [
          {
            'loc': ['body', 'password'],
            'msg': 'String should have at least 12 characters',
            'type': 'string_too_short',
          },
        ],
      }, statusCode: 422),
    );
    addTearDown(apiClient.close);
    final repository = AuthRepository(apiClient: apiClient);

    await expectLater(
      repository.login(email: 'user@example.com', password: 'short'),
      throwsA(
        isA<AuthException>()
            .having((error) => error.message, 'message', contains('kontrol'))
            .having(
              (error) => error.message,
              'does not expose validator internals',
              isNot(contains('characters')),
            ),
      ),
    );
  });

  test('başarılı yanıttaki sunucu metnini de kullanıcıya taşımaz', () async {
    final apiClient = _client(
      (_) => _jsonResponse({
        'message': 'smtp-server=internal-mail:2525 user_exists=true',
      }, statusCode: 202),
    );
    addTearDown(apiClient.close);
    final repository = AuthRepository(apiClient: apiClient);

    final message = await repository.register(
      email: 'user@example.com',
      password: 'A-strong-password-123',
    );

    expect(
      message,
      'Adres uygunsa doğrulama bağlantısı e-posta adresinize gönderildi.',
    );
    expect(message, isNot(contains('internal-mail')));
    expect(message, isNot(contains('user_exists')));
  });
}

ApiClient _client(ResponseBody Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _Adapter(handler);
  return ApiClient(
    baseUrl: 'https://example.test',
    tokenStorage: _TokenStorage(),
    dio: dio,
    refreshDio: Dio(BaseOptions(baseUrl: 'https://example.test')),
  );
}

ResponseBody _jsonResponse(
  Map<String, Object?> body, {
  required int statusCode,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

class _TokenStorage implements TokenStorage {
  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String token) async {}
}
