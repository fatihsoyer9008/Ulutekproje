import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/group_models.dart';
import 'group_repository.dart';

class ApiGroupExpenseRepository implements GroupExpenseRepository {
  ApiGroupExpenseRepository(this._apiClient);

  final ApiClient _apiClient;

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
      (sharesByLine[share.receiptLineItemId] ??= []).add(share);
    }
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
        'payer_user_id': request.payerUserId,
        'split': <String, Object?>{
          'type': 'itemized',
          'line_items': [
            for (final entry in sharesByLine.entries)
              <String, Object?>{
                'receipt_line_item_id': entry.key,
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
          'extra_amount_shares': [
            for (final share in request.extraShares)
              <String, Object?>{
                'user_id': share.userId,
                'amount_in_minor': share.amountInMinor,
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
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/groups/$groupId/expenses',
        data: body,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      final expense = response.data?['expense'];
      if (expense is! Map) {
        throw const FormatException('Grup harcaması cevabı geçersiz.');
      }
      return GroupExpense.fromJson(Map<String, Object?>.from(expense));
    } on DioException catch (error) {
      throw groupApiExceptionFromDio(error);
    }
  }

  @override
  Future<GroupExpense> createExpense(
    GroupExpense expense, {
    required String idempotencyKey,
  }) {
    return createFastSplit(
      FastSplitExpenseRequest(
        groupId: expense.groupId,
        title: expense.title,
        payerUserId: expense.payerUserId,
        expenseDate: expense.expenseDate,
        totalAmountInMinor: expense.totalAmountInMinor,
        currency: expense.currency,
        splitType: expense.splitType,
        orderedMemberIds: [for (final share in expense.shares) share.userId],
        fixedAmountsInMinor: {
          for (final share in expense.shares) share.userId: share.amountInMinor,
        },
      ),
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  }) async {
    final body = await _get('/api/v1/groups/$groupId/expenses/$expenseId');
    return _expense(body);
  }

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) async {
    final body = await _get('/api/v1/groups/$groupId/expenses');
    final expenses = body['expenses'];
    if (expenses is! List) {
      throw const FormatException('Grup harcamaları cevabı geçersiz.');
    }
    return [
      for (final item in expenses)
        if (item is Map) GroupExpense.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  Future<Map<String, Object?>> _get(String path) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(path);
      return Map<String, Object?>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw groupApiExceptionFromDio(error);
    }
  }

  GroupExpense _expense(Map<String, Object?> body) {
    final expense = body['expense'];
    if (expense is! Map) {
      throw const FormatException('Grup harcaması cevabı geçersiz.');
    }
    return GroupExpense.fromJson(Map<String, Object?>.from(expense));
  }
}

GroupApiException groupApiExceptionFromDio(DioException error) {
  final statusCode = error.response?.statusCode ?? 503;
  final body = error.response?.data;
  if (body is Map && body['detail'] is Map) {
    final detail = Map<String, Object?>.from(body['detail'] as Map);
    if (detail['code'] is String && detail['message'] is String) {
      return GroupApiException(
        statusCode: statusCode,
        error: GroupApiError.fromJson(<String, Object?>{'detail': detail}),
      );
    }
  }
  return GroupApiException(
    statusCode: statusCode,
    error: const GroupApiError(
      detail: GroupApiErrorDetail(
        code: 'service_unavailable',
        message: 'Grup harcaması kaydedilemedi. Lütfen tekrar deneyin.',
      ),
    ),
  );
}
