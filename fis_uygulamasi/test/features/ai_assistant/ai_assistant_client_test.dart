import 'dart:convert';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/ai_assistant/data/ai_assistant_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends timezone, timeout and displays answer metadata', () async {
    final adapter = _AssistantAdapter(
      statusCode: 200,
      responseBody: {
        'answer': 'Bu ay 125,00 TL harcadın.',
        'period_start': '2026-08-01',
        'period_end_exclusive': '2026-09-01',
        'data_as_of': '2026-08-06T10:30:00Z',
        'currency': 'TRY',
        'disclaimer': 'Bu bir yatırım tavsiyesi değildir.',
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
      refreshDio: Dio(),
    );
    await client.setSession(
      const AuthTokenBundle(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        user: <String, dynamic>{},
      ),
    );

    final assistantClient = AiAssistantClient(
      client,
      timezoneResolver: () async => 'America/New_York',
    );

    final chunks = await assistantClient
        .streamAnswer('Bu ay ne harcadım?')
        .toList();

    expect(
      chunks.join(),
      'Bu ay 125,00 TL harcadın.'
      '\n\nDönem: 2026-08-01 – 2026-09-01 (bitiş hariç)'
      '\nVeri güncelliği: 2026-08-06T10:30:00Z',
    );
    expect(adapter.headers?['Authorization'], 'Bearer access-token');
    expect(adapter.method, 'POST');
    expect(adapter.path, '/api/v1/assistant/query');
    expect(adapter.receiveTimeout, const Duration(seconds: 35));
    expect(adapter.requestBody, {
      'question': 'Bu ay ne harcadım?',
      'timezone': 'America/New_York',
    });
  });

  test('fetches assistant consent status', () async {
    final adapter = _AssistantAdapter(
      statusCode: 200,
      responseBody: {
        'enabled': true,
        'required_consent_version': '2026-08-01',
        'consent_granted': false,
        'consent_granted_at': null,
        'consent_revoked_at': null,
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final apiClient = ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
      refreshDio: Dio(),
    );

    final status = await AiAssistantClient(apiClient).fetchStatus();

    expect(adapter.method, 'GET');
    expect(adapter.path, '/api/v1/assistant/status');
    expect(status.enabled, isTrue);
    expect(status.requiredConsentVersion, '2026-08-01');
    expect(status.consentGranted, isFalse);
    expect(status.consentGrantedAt, isNull);
    expect(status.consentRevokedAt, isNull);
  });

  test('sends explicit assistant consent', () async {
    final adapter = _AssistantAdapter(
      statusCode: 200,
      responseBody: {
        'enabled': true,
        'required_consent_version': '2026-08-01',
        'consent_granted': true,
        'consent_granted_at': '2026-08-06T10:30:00Z',
        'consent_revoked_at': null,
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final apiClient = ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
      refreshDio: Dio(),
    );

    final status = await AiAssistantClient(
      apiClient,
    ).updateConsent(accepted: true, consentVersion: '2026-08-01');

    expect(adapter.method, 'PUT');
    expect(adapter.path, '/api/v1/assistant/consent');
    expect(adapter.requestBody, {
      'accepted': true,
      'consent_version': '2026-08-01',
    });
    expect(status.consentGranted, isTrue);
    expect(status.consentGrantedAt, DateTime.parse('2026-08-06T10:30:00Z'));
  });
  test('sends assistant consent revocation', () async {
    final adapter = _AssistantAdapter(
      statusCode: 200,
      responseBody: {
        'enabled': true,
        'required_consent_version': '2026-08-01',
        'consent_granted': false,
        'consent_granted_at': '2026-08-06T10:30:00Z',
        'consent_revoked_at': '2026-08-06T11:00:00Z',
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final apiClient = ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
      refreshDio: Dio(),
    );

    final status = await AiAssistantClient(
      apiClient,
    ).updateConsent(accepted: false, consentVersion: '2026-08-01');

    expect(adapter.method, 'PUT');
    expect(adapter.path, '/api/v1/assistant/consent');
    expect(adapter.requestBody, {
      'accepted': false,
      'consent_version': '2026-08-01',
    });
    expect(status.consentGranted, isFalse);
    expect(status.consentRevokedAt, DateTime.parse('2026-08-06T11:00:00Z'));
  });

  test('maps missing consent responses to a user friendly error', () async {
    final dio = Dio()
      ..httpClientAdapter = _AssistantAdapter(
        statusCode: 403,
        responseBody: {
          'detail': 'Current AI data processing consent is required.',
        },
      );
    final apiClient = ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
      refreshDio: Dio(),
    );

    expect(
      AiAssistantClient(
        apiClient,
        timezoneResolver: () async => 'Europe/Istanbul',
      ).streamAnswer('Sorum').toList(),
      throwsA(
        predicate(
          (error) => error.toString().contains('veri işleme izni vermelisin'),
        ),
      ),
    );
  });

  test('maps rate limit responses to a user friendly error', () async {
    final dio = Dio()
      ..httpClientAdapter = _AssistantAdapter(
        statusCode: 429,
        responseBody: {'detail': 'rate limited'},
      );
    final apiClient = ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
      refreshDio: Dio(),
    );

    expect(
      AiAssistantClient(
        apiClient,
        timezoneResolver: () async => 'Europe/Istanbul',
      ).streamAnswer('Sorum').toList(),
      throwsA(
        predicate(
          (error) => error.toString().contains('kullanım sınırına ulaşıldı'),
        ),
      ),
    );
  });
}

class _AssistantAdapter implements HttpClientAdapter {
  _AssistantAdapter({required this.statusCode, required this.responseBody});

  final int statusCode;
  final Map<String, dynamic> responseBody;

  Map<String, dynamic>? headers;
  Object? requestBody;
  String? method;
  String? path;
  Duration? receiveTimeout;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headers = Map<String, dynamic>.from(options.headers);
    requestBody = options.data;
    method = options.method;
    path = options.path;
    receiveTimeout = options.receiveTimeout;

    return ResponseBody.fromString(
      jsonEncode(responseBody),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> deleteRefreshToken() async => _token = null;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> writeRefreshToken(String token) async => _token = token;
}
