import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/installation_id_provider.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptParserErrorMapper', () {
    const mapper = ReceiptParserErrorMapper();
    final cases = <int, ({ReceiptParserFailureKind kind, String message})>{
      429: (
        kind: ReceiptParserFailureKind.rateLimited,
        message: 'Çok fazla fiş analizi isteği',
      ),
      413: (
        kind: ReceiptParserFailureKind.payloadTooLarge,
        message: 'işlenemeyecek kadar büyük',
      ),
      422: (
        kind: ReceiptParserFailureKind.validation,
        message: 'Fiş bilgileri doğrulanamadı',
      ),
    };

    for (final entry in cases.entries) {
      test('HTTP ${entry.key} için güvenli Türkçe hata üretir', () {
        final request = RequestOptions(path: '/api/v1/parse-receipt');
        final failure = mapper.map(
          DioException(
            requestOptions: request,
            response: Response<void>(
              requestOptions: request,
              statusCode: entry.key,
              data: null,
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        expect(failure.kind, entry.value.kind);
        expect(failure.message, contains(entry.value.message));
        expect(failure.message, isNot(contains('Dio')));
        expect(failure.message, isNot(contains('HTTP')));
      });
    }

    test('yalnızca 429 hatası aynı istekle tekrar denenebilir', () {
      expect(_mappedHttpFailure(mapper, 429).canRetry, isTrue);
      expect(_mappedHttpFailure(mapper, 413).canRetry, isFalse);
      expect(_mappedHttpFailure(mapper, 422).canRetry, isFalse);
    });
  });

  test('posts OCR text and maps the backend response to a draft', () async {
    final client = _clientWithResponse((options) {
      expect(options.method, 'POST');
      expect(options.path, '/api/v1/parse-receipt');
      expect(
        options.headers['X-Installation-ID'],
        'installation-test-1234567890',
      );
      expect(options.data, {'ocr_text': 'MIGROS TOPLAM 25,50 TL'});
      return _jsonResponse({
        'normalized_ocr_text': 'MIGROS\nTOPLAM 25,50 TL',
        'merchant': 'MIGROS',
        'total_amount_minor': 2550,
        'date': '2026-07-28T12:00:00Z',
        'category': 'Market',
        'confidence_score': 0.92,
        'is_parse_successful': true,
      });
    });

    final result = await client.parse('MIGROS TOPLAM 25,50 TL');

    expect(result.draft.institutionName, 'MIGROS');
    expect(result.draft.category, 'Market');
    expect(result.draft.amountInMinor, 2550);
    expect(result.draft.transactionDate, DateTime.utc(2026, 7, 28, 12));
    expect(result.draft.rawOcrText, isNull);
    expect(result.normalizedOcrText, 'MIGROS\nTOPLAM 25,50 TL');
    expect(result.confidenceScore, 0.92);
    expect(result.isParseSuccessful, isTrue);
  });

  test('sends the current JWT with an authenticated receipt request', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.httpClientAdapter = _FakeAdapter((options) {
      expect(options.path, '/api/v1/parse-receipt');
      expect(options.headers['Authorization'], 'Bearer current-access-token');
      expect(
        options.headers['X-Installation-ID'],
        'installation-test-1234567890',
      );
      return _jsonResponse({
        'normalized_ocr_text': 'MIGROS\nTOPLAM 25,50 TL',
        'merchant': 'MIGROS',
        'total_amount_minor': 2550,
        'date': null,
        'category': 'Market',
        'confidence_score': 0.92,
        'is_parse_successful': true,
      });
    });
    final apiClient = ApiClient(
      baseUrl: 'https://example.com',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
    );
    addTearDown(apiClient.close);
    await apiClient.setSession(
      const AuthTokenBundle(
        accessToken: 'current-access-token',
        refreshToken: 'current-refresh-token',
        user: {},
      ),
    );
    final client = ReceiptParserClient(
      apiClient: apiClient,
      installationIdProvider: const _FakeInstallationIdProvider(
        'installation-test-1234567890',
      ),
    );

    await client.parse('MIGROS TOPLAM 25,50 TL');
  });

  test('rejects an empty OCR text without making a request', () async {
    final client = _clientWithResponse((_) => fail('request must not happen'));

    expect(
      () => client.parse('   '),
      throwsA(
        isA<ReceiptParserException>().having(
          (error) => error.kind,
          'kind',
          ReceiptParserFailureKind.emptyOcr,
        ),
      ),
    );
  });

  for (final entry in <int, ReceiptParserFailureKind>{
    413: ReceiptParserFailureKind.payloadTooLarge,
    422: ReceiptParserFailureKind.validation,
    429: ReceiptParserFailureKind.rateLimited,
    501: ReceiptParserFailureKind.geminiUnavailable,
    502: ReceiptParserFailureKind.serviceUnavailable,
    503: ReceiptParserFailureKind.serviceConfiguration,
  }.entries) {
    test('maps HTTP ${entry.key} to a user-safe parser failure', () async {
      final client = _clientWithResponse(
        (_) => ResponseBody.fromString('upstream failure', entry.key),
      );

      expect(
        () => client.parse('MIGROS\nTOPLAM 25,50 TL'),
        throwsA(
          isA<ReceiptParserException>()
              .having((error) => error.kind, 'kind', entry.value)
              .having(
                (error) => error.message,
                'message',
                isNot(contains('Dio')),
              ),
        ),
      );
    });
  }

  test('maps timeout to a retryable user-safe parser failure', () async {
    final client = _clientWithResponse((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    });

    expect(
      () => client.parse('OCR'),
      throwsA(
        isA<ReceiptParserException>()
            .having(
              (error) => error.kind,
              'kind',
              ReceiptParserFailureKind.timeout,
            )
            .having((error) => error.canRetry, 'canRetry', isTrue),
      ),
    );
  });

  test('does not use the local fallback for a cancelled request', () async {
    final client = _clientWithResponse((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    });

    expect(
      () => client.parse('MIGROS\nTOPLAM 25,50 TL'),
      throwsA(
        isA<ReceiptParserException>().having(
          (error) => error.kind,
          'kind',
          ReceiptParserFailureKind.cancelled,
        ),
      ),
    );
  });

  test(
    'does not use the local fallback for an unsupported Dio error',
    () async {
      final client = _clientWithResponse((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badCertificate,
        );
      });

      expect(
        () => client.parse('MIGROS\nTOPLAM 25,50 TL'),
        throwsA(isA<ReceiptParserException>()),
      );
    },
  );

  test(
    'uses the local fallback for a timeout with a usable OCR amount',
    () async {
      final client = _clientWithResponse((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      });

      final result = await client.parse('MIGROS\nTOPLAM 25,50 TL');

      expect(result.usedLocalFallback, isTrue);
      expect(result.draft.amountInMinor, 2550);
    },
  );

  test(
    'maps DNS lookup failures without exposing SocketException details',
    () async {
      final client = _clientWithResponse((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Failed host lookup'),
        );
      });

      expect(
        () => client.parse('OCR'),
        throwsA(
          isA<ReceiptParserException>()
              .having(
                (error) => error.kind,
                'kind',
                ReceiptParserFailureKind.dns,
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('SocketException')),
              ),
        ),
      );
    },
  );

  test(
    'maps an offline connection failure to the internet guidance message',
    () async {
      final client = _clientWithResponse((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      expect(
        () => client.parse('OCR'),
        throwsA(
          isA<ReceiptParserException>()
              .having(
                (error) => error.kind,
                'kind',
                ReceiptParserFailureKind.noInternet,
              )
              .having(
                (error) => error.message,
                'message',
                contains('İnternet'),
              ),
        ),
      );
    },
  );

  test('does not classify a connection reset as a DNS failure', () async {
    final client = _clientWithResponse((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException('Connection reset by peer'),
      );
    });

    expect(
      () => client.parse('OCR'),
      throwsA(
        isA<ReceiptParserException>().having(
          (error) => error.kind,
          'kind',
          ReceiptParserFailureKind.noInternet,
        ),
      ),
    );
  });

  test('rejects a malformed backend response as invalidResponse', () async {
    final client = _clientWithResponse(
      (_) => _jsonResponse({
        'normalized_ocr_text': 'OCR',
        'confidence_score': 'not-a-number',
        'is_parse_successful': true,
      }),
    );

    expect(
      () => client.parse('OCR'),
      throwsA(
        isA<ReceiptParserException>().having(
          (error) => error.kind,
          'kind',
          ReceiptParserFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test(
    'uses a low-confidence local fallback when the server is unreachable',
    () async {
      final client = _clientWithResponse((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      final result = await client.parse('MIGROS\nTOPLAM 25,50 TL');

      expect(result.usedLocalFallback, isTrue);
      expect(result.isParseSuccessful, isFalse);
      expect(result.confidenceScore, lessThan(.70));
      expect(result.draft.institutionName, 'MIGROS');
      expect(result.draft.amountInMinor, 2550);
    },
  );

  test('parses a dotted decimal amount in the local fallback', () async {
    final client = _clientWithResponse((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    final result = await client.parse('MIGROS\nTOPLAM 25.50 TL');

    expect(result.usedLocalFallback, isTrue);
    expect(result.draft.amountInMinor, 2550);
  });

  for (final entry in <String, int>{
    '25,50': 2550,
    '25.50': 2550,
    '1.234,56': 123456,
    '1,234.56': 123456,
  }.entries) {
    test('normalizes ${entry.key} in the local fallback', () async {
      final client = _clientWithResponse((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      final result = await client.parse('MIGROS\nTOPLAM ${entry.key} TL');

      expect(result.usedLocalFallback, isTrue);
      expect(result.draft.amountInMinor, entry.value);
    });
  }

  test('prefers the amount on a total line over KDV and ara toplam', () async {
    final client = _clientWithResponse((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    final result = await client.parse(
      'MIGROS\nARA TOPLAM 20,00 TL\nKDV 4,00 TL\nGENEL TOPLAM 24,00 TL',
    );

    expect(result.usedLocalFallback, isTrue);
    expect(result.draft.amountInMinor, 2400);
  });

  test('keeps genel toplam priority when toplam KDV appears later', () async {
    final client = _clientWithResponse((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    final result = await client.parse(
      'MIGROS\nGENEL TOPLAM 100,00 TL\nTOPLAM KDV 20,00 TL',
    );

    expect(result.usedLocalFallback, isTrue);
    expect(result.draft.amountInMinor, 10000);
  });
}

ReceiptParserException _mappedHttpFailure(
  ReceiptParserErrorMapper mapper,
  int statusCode,
) {
  final request = RequestOptions(path: '/api/v1/parse-receipt');
  return mapper.map(
    DioException(
      requestOptions: request,
      response: Response<void>(requestOptions: request, statusCode: statusCode),
      type: DioExceptionType.badResponse,
    ),
  );
}

ReceiptParserClient _clientWithResponse(
  ResponseBody Function(RequestOptions) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
  dio.httpClientAdapter = _FakeAdapter(handler);
  return ReceiptParserClient(
    apiClient: ApiClient(
      baseUrl: 'https://example.com',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
    ),
    installationIdProvider: const _FakeInstallationIdProvider(
      'installation-test-1234567890',
    ),
  );
}

ResponseBody _jsonResponse(Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

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

class _FakeInstallationIdProvider implements InstallationIdProvider {
  const _FakeInstallationIdProvider(this.installationId);

  final String installationId;

  @override
  Future<String> getInstallationId() async => installationId;
}
