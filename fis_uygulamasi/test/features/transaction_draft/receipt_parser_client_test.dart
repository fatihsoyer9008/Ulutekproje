import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('posts OCR text and maps the backend response to a draft', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.httpClientAdapter = _FakeAdapter((options) {
      expect(options.method, 'POST');
      expect(options.path, '/api/v1/parse-receipt');
      expect(options.data, {'ocr_text': 'MİGROS TOPLAM 25,50 TL'});
      return ResponseBody.fromString(
        jsonEncode({
          'normalized_ocr_text': 'MİGROS\nTOPLAM 25,50 TL',
          'merchant': 'MİGROS',
          'total_amount_minor': 2550,
          'currency': 'TRY',
          'date': '2026-07-28T12:00:00Z',
          'category': 'Market',
          'confidence_score': 0.92,
          'is_parse_successful': true,
          'items': <Object>[],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    final apiClient = ApiClient(
      baseUrl: 'https://example.com',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
    );
    final client = ReceiptParserClient(apiClient: apiClient);

    final result = await client.parse('MİGROS TOPLAM 25,50 TL');

    expect(result.draft.institutionName, 'MİGROS');
    expect(result.draft.category, 'Market');
    expect(result.draft.amountInMinor, 2550);
    expect(result.draft.transactionDate, DateTime.utc(2026, 7, 28, 12));
    expect(result.normalizedOcrText, 'MİGROS\nTOPLAM 25,50 TL');
    expect(result.confidenceScore, 0.92);
    expect(result.isParseSuccessful, isTrue);
    apiClient.close();
  });

  test('throws a readable error for a non-success response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.httpClientAdapter = _FakeAdapter(
      (_) => ResponseBody.fromString('error', 502),
    );
    final apiClient = ApiClient(
      baseUrl: 'https://example.com',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
    );
    final client = ReceiptParserClient(apiClient: apiClient);

    expect(
      () => client.parse('OCR'),
      throwsA(
        isA<ReceiptParserException>().having(
          (error) => error.message,
          'message',
          contains('502'),
        ),
      ),
    );
    apiClient.close();
  });
}

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
