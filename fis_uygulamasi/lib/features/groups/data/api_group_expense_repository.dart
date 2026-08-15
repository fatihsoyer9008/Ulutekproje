import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/group_models.dart';
import 'group_api_failure.dart';
import 'group_api_models.dart';
import 'group_repository.dart';

class ApiGroupExpenseRepository implements GroupExpenseRepository {
  ApiGroupExpenseRepository(this._apiClient);

  final ApiClient _apiClient;
  bool _lastCreateWasReplay = false;

  bool get lastCreateWasReplay => _lastCreateWasReplay;

  @override
  Future<GroupExpense> createFastSplit(
    FastSplitExpenseRequest request, {
    required String idempotencyKey,
  }) {
    final split = switch (request.splitType) {
      SplitType.equal => <String, Object?>{
        'type': 'equal',
        'member_ids': request.orderedMemberIds,
      },
      SplitType.percentage => <String, Object?>{
        'type': 'percentage',
        'shares': [
          for (final userId in request.orderedMemberIds)
            <String, Object?>{
              'user_id': userId,
              'percentage_basis_points': request.percentageBasisPoints[userId],
            },
        ],
      },
      SplitType.fixedAmount => <String, Object?>{
        'type': 'fixed_amount',
        'shares': [
          for (final userId in request.orderedMemberIds)
            <String, Object?>{
              'user_id': userId,
              'amount_in_minor': request.fixedAmountsInMinor[userId],
            },
        ],
      },
      SplitType.itemized => throw ArgumentError.value(
        request.splitType,
        'splitType',
        'Kalem bazlı bölüştürme createItemizedSplit ile gönderilmelidir.',
      ),
    };
    return _create(
      groupId: request.groupId,
      idempotencyKey: idempotencyKey,
      body: <String, Object?>{
        'title': request.title,
        'note': null,
        'expense_date': request.expenseDate,
        'total_amount_in_minor': request.totalAmountInMinor,
        'currency': request.currency,
        'receipt_id': null,
        'payer_user_id': request.payerUserId,
        'split': split,
      },
    );
  }

  @override
  Future<GroupExpense> createItemizedSplit(
    ItemizedExpenseRequest request, {
    required String idempotencyKey,
  }) {
    final sharesByLine = <String, List<ItemizedLineShareInput>>{};

    for (final share in request.lineShares) {
      final key =
          share.receiptLineItemId ??
          'position:${share.receiptLineItemPosition}';
      (sharesByLine[key] ??= []).add(share);
    }

    final extraAmountInMinor = request.extraShares.fold<int>(
      0,
      (total, share) => total + share.amountInMinor,
    );
    final receiptDraft = request.receiptDraft;
    final extraAmounts = request.extraAmounts.isNotEmpty
        ? request.extraAmounts
        : <ItemizedExtraAmountInput>[
            if (extraAmountInMinor > 0)
              ItemizedExtraAmountInput(
                type: ExpenseExtraAmountType.other,
                label: 'Fiş toplam farkı',
                amountInMinor: extraAmountInMinor,
                shares: request.extraShares,
              ),
          ];

    return _create(
      groupId: request.groupId,
      idempotencyKey: idempotencyKey,
      body: <String, Object?>{
        'title': request.title,
        'note': null,
        'expense_date': request.expenseDate,
        'total_amount_in_minor': request.totalAmountInMinor,
        'currency': request.currency,
        'receipt_id': request.receiptId,
        if (receiptDraft != null)
          'receipt_draft': <String, Object?>{
            'merchant_name': receiptDraft.merchantName,
            'category': receiptDraft.category,
            'raw_ocr_text': receiptDraft.rawOcrText,
            'line_items': [
              for (final line in receiptDraft.lineItems)
                <String, Object?>{
                  'position': line.position,
                  'name': line.name,
                  'category': line.category,
                  'quantity_milli': line.quantityMilli,
                  'unit_price_in_minor': line.unitPriceInMinor,
                  'total_amount_in_minor': line.totalAmountInMinor,
                  'tax_rate_basis_points': line.taxRateBasisPoints,
                  'tax_amount_in_minor': line.taxAmountInMinor,
                },
            ],
          },
        'payer_user_id': request.payerUserId,
        'split': <String, Object?>{
          'type': 'itemized',
          'line_items': [
            for (final entry in sharesByLine.entries)
              <String, Object?>{
                if (entry.value.first.receiptLineItemId != null)
                  'receipt_line_item_id': entry.value.first.receiptLineItemId,
                if (entry.value.first.receiptLineItemPosition != null)
                  'receipt_line_item_position':
                      entry.value.first.receiptLineItemPosition,
                'shares': [
                  for (final share in entry.value)
                    <String, Object?>{
                      'user_id': share.userId,
                      'amount_in_minor': share.amountInMinor,
                      'quantity_share_milli': share.quantityShareMilli,
                    },
                ],
              },
          ],
          'extra_amounts': [
            for (final extra in extraAmounts)
              <String, Object?>{
                'type': switch (extra.type) {
                  ExpenseExtraAmountType.tax => 'tax',
                  ExpenseExtraAmountType.tip => 'tip',
                  ExpenseExtraAmountType.serviceFee => 'service_fee',
                  ExpenseExtraAmountType.other => 'other',
                },
                'label': extra.label,
                'amount_in_minor': extra.amountInMinor,
                'shares': [
                  for (final share in extra.shares)
                    <String, Object?>{
                      'user_id': share.userId,
                      'amount_in_minor': share.amountInMinor,
                    },
                ],
              },
          ],
        },
      },
    );
  }

  Future<GroupExpense> _create({
    required String groupId,
    required String idempotencyKey,
    required Map<String, Object?> body,
  }) async {
    if (!_uuidV4.hasMatch(idempotencyKey)) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
        'Masraf oluşturma anahtarı UUIDv4 formatında olmalıdır.',
      );
    }
    _lastCreateWasReplay = false;
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/groups/$groupId/expenses',
        data: body,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      _lastCreateWasReplay =
          response.headers.value('Idempotency-Replayed')?.toLowerCase() ==
          'true';
      final responseBody = Map<String, Object?>.from(response.data ?? const {});
      return GroupExpenseEnvelopeApiResponse.fromJson(responseBody).toDomain();
    } on DioException catch (error) {
      throw groupApiExceptionFromDio(
        error,
        fallbackMessage: 'Harcama kaydedilemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  @override
  Future<GroupExpense> createExpense(
    CreateGroupExpenseRequest request, {
    required String idempotencyKey,
  }) => _create(
    groupId: request.groupId,
    idempotencyKey: idempotencyKey,
    body: request.toJson(),
  );

  @override
  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  }) async {
    final body = await _get('/api/v1/groups/$groupId/expenses/$expenseId');
    return GroupExpenseEnvelopeApiResponse.fromJson(body).toDomain();
  }

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) async {
    final body = await _get('/api/v1/groups/$groupId/expenses');
    return GroupExpensesApiResponse.fromJson(body).toDomain();
  }

  Future<Map<String, Object?>> _get(String path) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(path);
      return Map<String, Object?>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw groupApiExceptionFromDio(
        error,
        fallbackMessage: 'Grup harcamaları alınamadı. Lütfen tekrar deneyin.',
      );
    }
  }
}

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
