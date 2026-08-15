import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/installation_id_provider.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'auth ve installation headerlarını her korumalı istekte taşır',
    () async {
      late RequestOptions captured;
      final adapter = _HandlerAdapter((options) async {
        captured = options;
        return _jsonResponse({'ok': true});
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter;
      final client = ApiClient(
        baseUrl: 'https://example.com',
        tokenStorage: _MemoryTokenStorage(),
        installationIdProvider: const _InstallationIdProvider(),
        dio: dio,
      );
      addTearDown(client.close);
      await client.setSession(
        const AuthTokenBundle(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          user: <String, dynamic>{},
        ),
      );

      await client.dio.get<Map<String, dynamic>>('/protected');

      expect(captured.headers['Authorization'], 'Bearer access-token');
      expect(captured.headers['X-Installation-Id'], 'installation-123456789');
    },
  );

  test('eş zamanlı 401 cevapları yalnızca bir refresh isteği üretir', () async {
    final storage = _MemoryTokenStorage()..token = 'r' * 32;
    var refreshCount = 0;
    final adapter = _HandlerAdapter((options) async {
      if (options.path == '/api/v1/auth/refresh') {
        refreshCount++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _jsonResponse({
          'access_token': 'new-access-token',
          'refresh_token': 'n' * 32,
          'user': {
            'id': 'user-id',
            'email': 'test@example.com',
            'display_name': 'Test',
            'is_email_verified': true,
          },
        });
      }
      if (options.headers['Authorization'] == 'Bearer new-access-token') {
        return _jsonResponse({'ok': true});
      }
      return _jsonResponse({'detail': 'unauthorized'}, statusCode: 401);
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = adapter;
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = adapter;
    final client = ApiClient(
      baseUrl: 'https://example.com',
      tokenStorage: storage,
      dio: dio,
      refreshDio: refreshDio,
    );
    addTearDown(client.close);

    final responses = await Future.wait([
      client.dio.get<Map<String, dynamic>>('/protected/one'),
      client.dio.get<Map<String, dynamic>>('/protected/two'),
    ]);

    expect(refreshCount, 1);
    expect(responses.every((response) => response.data?['ok'] == true), isTrue);
    expect(storage.token, 'n' * 32);
  });

  test(
    'başarısız refresh oturumu temizler ve unauthorized olayı yayar',
    () async {
      final storage = _MemoryTokenStorage()..token = 'r' * 32;
      final adapter = _HandlerAdapter(
        (options) async =>
            _jsonResponse({'detail': 'unauthorized'}, statusCode: 401),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter;
      final refreshDio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter;
      final client = ApiClient(
        baseUrl: 'https://example.com',
        tokenStorage: storage,
        dio: dio,
        refreshDio: refreshDio,
      );
      addTearDown(client.close);
      await client.setSession(
        AuthTokenBundle(
          accessToken: 'expired-access-token',
          refreshToken: storage.token!,
          user: const <String, dynamic>{},
        ),
      );
      final unauthorized = client.unauthorizedEvents.first;

      await expectLater(
        client.dio.get<Map<String, dynamic>>('/protected'),
        throwsA(isA<DioException>()),
      );
      await unauthorized.timeout(const Duration(seconds: 1));

      expect(client.hasAccessToken, isFalse);
      expect(storage.token, isNull);
    },
  );
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _HandlerAdapter implements HttpClientAdapter {
  _HandlerAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> deleteRefreshToken() async => token = null;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> writeRefreshToken(String token) async => this.token = token;
}

class _InstallationIdProvider implements InstallationIdProvider {
  const _InstallationIdProvider();

  @override
  Future<String> getInstallationId() async => 'installation-123456789';
}
