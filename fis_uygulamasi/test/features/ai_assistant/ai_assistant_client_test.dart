import 'package:dio/dio.dart';
import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/ai_assistant/data/ai_assistant_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sends the authenticated assistant request and streams its answer',
    () async {
      final adapter = _AssistantAdapter(
        statusCode: 200,
        responseBody: {'answer': 'Bu ay 125,00 TL harcadın.'},
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

      final chunks = await AiAssistantClient(
        client,
      ).streamAnswer('Bu ay ne harcadım?').toList();

      expect(chunks.join(), 'Bu ay 125,00 TL harcadın.');
      expect(adapter.headers?['Authorization'], 'Bearer access-token');
      expect(adapter.requestBody, {
        'question': 'Bu ay ne harcadım?',
        'timezone': 'Europe/Istanbul',
      });
    },
  );

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
      AiAssistantClient(apiClient).streamAnswer('Sorum').toList(),
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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headers = Map<String, dynamic>.from(options.headers);
    requestBody = options.data;
    return ResponseBody.fromString(
      _encodeJson(responseBody),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _encodeJson(Map<String, dynamic> value) {
  final entries = value.entries
      .map((entry) => '"${entry.key}":"${entry.value}"')
      .join(',');
  return '{$entries}';
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
