import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/group_models.dart';
import 'api_group_expense_repository.dart';
import 'group_repository.dart';

class ApiGroupRepository implements GroupRepository {
  ApiGroupRepository(this._apiClient)
    : _expenses = ApiGroupExpenseRepository(_apiClient);

  final ApiClient _apiClient;
  final ApiGroupExpenseRepository _expenses;

  @override
  Future<GroupsResponse> listGroups({bool includeArchived = false}) async {
    final body = await _get(
      '/api/v1/groups',
      queryParameters: {'include_archived': includeArchived},
    );
    return GroupsResponse.fromJson(body);
  }

  @override
  Future<GroupDetail> getGroup(String groupId) async {
    final body = await _get('/api/v1/groups/$groupId');
    return GroupDetail.fromJson(_envelope(body, 'group'));
  }

  @override
  Future<GroupDetail> createGroup({
    required String name,
    String? description,
    String currency = 'TRY',
  }) async {
    final body = await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/groups',
        data: {'name': name, 'description': description, 'currency': currency},
      ),
    );
    return GroupDetail.fromJson(_envelope(body, 'group'));
  }

  @override
  Future<GroupDetail> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool clearDescription = false,
  }) async {
    final body = await _send(
      () => _apiClient.dio.patch<Map<String, dynamic>>(
        '/api/v1/groups/$groupId',
        data: {
          'name': ?name,
          if (description != null || clearDescription)
            'description': clearDescription ? null : description,
        },
      ),
    );
    return GroupDetail.fromJson(_envelope(body, 'group'));
  }

  @override
  Future<void> archiveGroup(String groupId) async {
    await _send(
      () => _apiClient.dio.delete<Map<String, dynamic>>(
        '/api/v1/groups/$groupId',
      ),
    );
  }

  @override
  Future<GroupMember> addMember({
    required String groupId,
    required String userId,
    required String displayName,
    GroupRole role = GroupRole.member,
  }) async {
    final body = await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/groups/$groupId/members',
        data: {'user_id': userId, 'role': role.name},
      ),
    );
    return GroupMember.fromJson(_envelope(body, 'member'));
  }

  Future<Map<String, Object?>> _get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) => _send(
    () => _apiClient.dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
    ),
  );

  Future<Map<String, Object?>> _send(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      return Map<String, Object?>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw groupApiExceptionFromDio(error);
    }
  }

  Map<String, Object?> _envelope(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is! Map) throw const FormatException('Grup cevabı geçersiz.');
    return Map<String, Object?>.from(value);
  }

  @override
  Future<GroupExpense> createExpense(
    CreateGroupExpenseRequest request, {
    required String idempotencyKey,
  }) => _expenses.createExpense(request, idempotencyKey: idempotencyKey);

  @override
  Future<GroupExpense> createFastSplit(
    FastSplitExpenseRequest request, {
    required String idempotencyKey,
  }) => _expenses.createFastSplit(request, idempotencyKey: idempotencyKey);

  @override
  Future<GroupExpense> createItemizedSplit(
    ItemizedExpenseRequest request, {
    required String idempotencyKey,
  }) => _expenses.createItemizedSplit(request, idempotencyKey: idempotencyKey);

  @override
  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  }) => _expenses.getExpense(groupId: groupId, expenseId: expenseId);

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) =>
      _expenses.listExpenses(groupId);

  @override
  Future<DebtSummary> getDebtSummary(String groupId) async {
    final body = await _get('/api/v1/groups/$groupId/debts');
    return DebtSummary.fromJson(body);
  }

  @override
  Future<List<Settlement>> listSettlements(String groupId) async {
    final body = await _get('/api/v1/groups/$groupId/settlements');
    final values = body['settlements'];

    if (values is! List) {
      throw const FormatException('Settlement listesi cevabı geçersiz.');
    }

    return [
      for (final value in values)
        if (value is Map)
          Settlement.fromJson(Map<String, Object?>.from(value))
        else
          throw const FormatException('Settlement listesi elemanı geçersiz.'),
    ];
  }

  @override
  Future<Settlement> createSettlement(
    Settlement settlement, {
    required String idempotencyKey,
  }) async {
    final body = await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/groups/${settlement.groupId}/settlements',
        data: {
          'from_user_id': settlement.fromUserId,
          'to_user_id': settlement.toUserId,
          'amount_in_minor': settlement.amountInMinor,
          'currency': settlement.currency,
          'settled_at': settlement.settledAt,
          'note': settlement.note,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      ),
    );

    return Settlement.fromJson(_envelope(body, 'settlement'));
  }

  @override
  Future<void> createInvitation({
    required String groupId,
    required String email,
    GroupRole role = GroupRole.member,
  }) => throw UnsupportedError('Davet endpointi henüz kullanılamıyor.');

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _send(
      () => _apiClient.dio.delete<Map<String, dynamic>>(
        '/api/v1/groups/$groupId/members/$userId',
      ),
    );
  }
}
