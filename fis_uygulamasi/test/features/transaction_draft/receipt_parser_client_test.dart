import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('posts OCR text and maps the backend response to a draft', () async {
    final client = _clientWithResponse((options) {
      expect(options.method, 'POST');
      expect(options.path, '/api/v1/parse-receipt');
      expect(options.data, {'ocr_text': 'MIGROS TOPLAM 25,50 TL'});
      return _jsonResponse({
        'normalized_ocr_text': 'MIGROS\nTOPLAM 25,50 TL',
        'merchant': 'MIGROS',
        'total_amount_minor': 2550,
        'category': 'Market',
        'confidence_score': 0.92,
        'is_parse_successful': true,
      });
    });

    final result = await client.parse('MIGROS TOPLAM 25,50 TL');

    expect(result.draft.institutionName, 'MIGROS');
    expect(result.draft.category, 'Market');
    expect(result.draft.amountInMinor, 2550);
    expect(result.normalizedOcrText, 'MIGROS\nTOPLAM 25,50 TL');
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
    501: ReceiptParserFailureKind.geminiUnavailable,
    502: ReceiptParserFailureKind.serviceUnavailable,
    503: ReceiptParserFailureKind.serviceConfiguration,
  }.entries) {
    test('maps HTTP ${entry.key} to a user-safe parser failure', () async {
      final client = _clientWithResponse(
        (_) => ResponseBody.fromString('upstream failure', entry.key),
      );

      expect(
        () => client.parse('OCR'),
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
