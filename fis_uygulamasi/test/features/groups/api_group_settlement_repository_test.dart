import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/groups/data/api_group_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  test(
    'create settlement sends contract body and idempotency header',
    () async {
      late RequestOptions captured;
      final repository = ApiGroupRepository(
        _client((options) {
          captured = options;
          return _jsonResponse({
            'settlement': sampleSettlement.toJson(),
          }, statusCode: 201);
        }),
      );

      final result = await repository.createSettlement(
        sampleSettlement,
        idempotencyKey: 'settlement-mobile-0001',
      );

      expect(captured.path, '/api/v1/groups/$twoMemberGroupId/settlements');
      expect(captured.headers['Idempotency-Key'], 'settlement-mobile-0001');
      expect(captured.data, {
        'from_user_id': sampleSettlement.fromUserId,
        'to_user_id': sampleSettlement.toUserId,
        'amount_in_minor': sampleSettlement.amountInMinor,
        'currency': sampleSettlement.currency,
        'settled_at': sampleSettlement.settledAt,
        'note': sampleSettlement.note,
      });
      expect(result.toJson(), sampleSettlement.toJson());
    },
  );

  test('list settlements decodes response envelope', () async {
    final repository = ApiGroupRepository(
      _client((options) {
        expect(options.path, '/api/v1/groups/$twoMemberGroupId/settlements');
        return _jsonResponse({
          'settlements': [sampleSettlement.toJson()],
        });
      }),
    );

    final result = await repository.listSettlements(twoMemberGroupId);

    expect(result, hasLength(1));
    expect(result.single.toJson(), sampleSettlement.toJson());
  });

  test('debt summary decodes the live API response', () async {
    final repository = ApiGroupRepository(
      _client((options) {
        expect(options.path, '/api/v1/groups/$twoMemberGroupId/debts');
        return _jsonResponse(currentUserDebtorDebtSummary.toJson());
      }),
    );

    final result = await repository.getDebtSummary(twoMemberGroupId);

    expect(result.toJson(), currentUserDebtorDebtSummary.toJson());
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

ResponseBody _jsonResponse(Map<String, Object?> body, {int statusCode = 200}) {
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
  ) async {
    return handler(options);
  }

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
