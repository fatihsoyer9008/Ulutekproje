import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/groups/data/api_group_expense_repository.dart';
import 'package:app_main/features/groups/data/group_repository.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  test(
    'percentage request preserves basis points and idempotency header',
    () async {
      late RequestOptions captured;
      final repository = ApiGroupExpenseRepository(
        _client((options) {
          captured = options;
          return _jsonResponse({'expense': fastSplitTransferExpense.toJson()});
        }),
      );

      await repository.createFastSplit(
        const FastSplitExpenseRequest(
          groupId: twoMemberGroupId,
          title: 'Akşam yemeği',
          payerUserId: currentUserId,
          expenseDate: '2026-08-12T20:00:00Z',
          totalAmountInMinor: 10000,
          currency: 'TRY',
          splitType: SplitType.percentage,
          orderedMemberIds: [currentUserId, secondUserId],
          percentageBasisPoints: {currentUserId: 3333, secondUserId: 6667},
        ),
        idempotencyKey: 'percentage-request-1',
      );

      expect(captured.path, '/api/v1/groups/$twoMemberGroupId/expenses');
      expect(captured.headers['Idempotency-Key'], 'percentage-request-1');
      final split = (captured.data as Map<String, Object?>)['split']! as Map;
      expect(split['type'], 'percentage');
      expect((split['shares'] as List).first, {
        'user_id': currentUserId,
        'percentage_basis_points': 3333,
      });
    },
  );

  test('itemized request groups shares by cloud line item', () async {
    late RequestOptions captured;
    final repository = ApiGroupExpenseRepository(
      _client((options) {
        captured = options;
        return _jsonResponse({'expense': itemizedMarketExpense.toJson()});
      }),
    );

    await repository.createItemizedSplit(
      const ItemizedExpenseRequest(
        groupId: twoMemberGroupId,
        receiptId: '20000000-0000-4000-8000-000000000001',
        title: 'Market',
        payerUserId: currentUserId,
        expenseDate: '2026-08-12T12:00:00Z',
        totalAmountInMinor: 12500,
        currency: 'TRY',
        lineShares: [
          ItemizedLineShareInput(
            receiptLineItemId: '30000000-0000-4000-8000-000000000001',
            userId: currentUserId,
            amountInMinor: 6000,
            quantityShareMilli: 1000,
          ),
        ],
        extraShares: [
          ItemizedExtraShareInput(userId: currentUserId, amountInMinor: 6500),
        ],
      ),
      idempotencyKey: 'itemized-request-1',
    );

    final split = (captured.data as Map<String, Object?>)['split']! as Map;
    expect(split['type'], 'itemized');
    expect(split['line_items'], hasLength(1));
    expect(split['extra_amounts'], hasLength(1));
    final extraAmount = (split['extra_amounts'] as List).single as Map;
    expect(extraAmount['type'], 'other');
    expect(extraAmount['label'], 'Fiş toplam farkı');
    expect(extraAmount['amount_in_minor'], 6500);
    expect(extraAmount['shares'], hasLength(1));
  });

  test(
    'generic create rejects splits whose source data cannot be recovered',
    () {
      final repository = ApiGroupExpenseRepository(
        _client((_) => throw StateError('HTTP request should not be sent')),
      );
      final percentageJson = Map<String, Object?>.from(
        fastSplitTransferExpense.toJson(),
      )..['split_type'] = 'percentage';
      final itemizedJson = Map<String, Object?>.from(
        itemizedMarketExpense.toJson(),
      );

      expect(
        () => repository.createExpense(
          GroupExpense.fromJson(percentageJson),
          idempotencyKey: 'generic-percentage-1',
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.createExpense(
          GroupExpense.fromJson(itemizedJson),
          idempotencyKey: 'generic-itemized-1',
        ),
        throwsArgumentError,
      );
    },
  );
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

ResponseBody _jsonResponse(Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

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
