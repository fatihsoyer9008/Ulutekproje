import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/pending_receipts/data/pending_receipts_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list() sunucudaki taslak fişleri ayrıştırır', () async {
    final fixture = _GatewayFixture(
      handler: (options) async => _jsonResponse([
        {
          'id': 'receipt-1',
          'merchant_name': 'Örnek Market',
          'total_amount_in_minor': 12550,
          'currency': 'TRY',
          'receipt_date': '2026-08-17T10:00:00Z',
          'category': 'market',
          'normalized_ocr_text': null,
          'created_at': '2026-08-17T12:30:00Z',
        },
      ]),
    );
    addTearDown(fixture.close);

    final receipts = await fixture.gateway.list();

    expect(fixture.lastRequest?.method, 'GET');
    expect(fixture.lastRequest?.path, '/api/v1/receipts/pending');
    expect(receipts, hasLength(1));
    expect(receipts.single.id, 'receipt-1');
    expect(receipts.single.merchantName, 'Örnek Market');
    expect(receipts.single.totalAmountInMinor, 12550);
    expect(receipts.single.category, 'market');
  });

  test('approve() düzenlenen alanları gövdede gönderir', () async {
    Map<String, dynamic>? sentBody;
    final fixture = _GatewayFixture(
      handler: (options) async {
        sentBody = Map<String, dynamic>.from(options.data as Map);
        return _jsonResponse({
          'id': 'receipt-1',
          'merchant_name': 'Edited Market',
          'total_amount_in_minor': 999,
          'currency': 'TRY',
          'receipt_date': null,
          'category': null,
          'normalized_ocr_text': null,
          'created_at': '2026-08-17T12:30:00Z',
        });
      },
    );
    addTearDown(fixture.close);

    final approved = await fixture.gateway.approve(
      'receipt-1',
      merchantName: 'Edited Market',
      totalAmountInMinor: 999,
    );

    expect(fixture.lastRequest?.method, 'POST');
    expect(fixture.lastRequest?.path, '/api/v1/receipts/receipt-1/approve');
    expect(sentBody, {
      'merchant_name': 'Edited Market',
      'total_amount_in_minor': 999,
    });
    expect(approved.merchantName, 'Edited Market');
    expect(approved.totalAmountInMinor, 999);
  });

  test('reject() reddetme endpointine post eder', () async {
    final fixture = _GatewayFixture(
      handler: (options) async => _jsonResponse({
        'id': 'receipt-1',
        'merchant_name': null,
        'total_amount_in_minor': null,
        'currency': 'TRY',
        'receipt_date': null,
        'category': null,
        'normalized_ocr_text': null,
        'created_at': '2026-08-17T12:30:00Z',
      }),
    );
    addTearDown(fixture.close);

    final rejected = await fixture.gateway.reject('receipt-1');

    expect(fixture.lastRequest?.method, 'POST');
    expect(fixture.lastRequest?.path, '/api/v1/receipts/receipt-1/reject');
    expect(rejected.id, 'receipt-1');
  });
}

ResponseBody _jsonResponse(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _GatewayFixture {
  _GatewayFixture({
    required Future<ResponseBody> Function(RequestOptions options) handler,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _FakeAdapter((options) async {
        lastRequest = options;
        return handler(options);
      });
    apiClient = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
      refreshDio: Dio(BaseOptions(baseUrl: 'https://example.test')),
    );
    gateway = DioPendingReceiptsGateway(apiClient: apiClient);
  }

  late final ApiClient apiClient;
  late final DioPendingReceiptsGateway gateway;
  RequestOptions? lastRequest;

  void close() => apiClient.close();
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

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
  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String token) async {}
}
