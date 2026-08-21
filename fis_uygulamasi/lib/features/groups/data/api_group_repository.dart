import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/group_models.dart';
import 'api_group_expense_repository.dart';
import 'group_api_failure.dart';
import 'group_api_models.dart';
import 'group_repository.dart';

class ApiGroupRepository implements GroupRepository {
  ApiGroupRepository(this._apiClient)
    : _expenses = ApiGroupExpenseRepository(_apiClient);

  @override
  GroupRepositoryCapabilities get capabilities =>
      const GroupRepositoryCapabilities(supportsInvitations: true);

  final ApiClient _apiClient;
  final ApiGroupExpenseRepository _expenses;

  @override
  Future<GroupsResponse> listGroups({bool includeArchived = false}) async {
    final body = await _get(
      '/api/v1/groups',
      queryParameters: {'include_archived': includeArchived},
    );
    return GroupsApiResponse.fromJson(body).toDomain();
  }

  @override
  Future<GroupDetail> getGroup(String groupId) async {
    final detailBody = await _get('/api/v1/groups/$groupId');
    final detail = GroupEnvelopeApiResponse.fromJson(detailBody).toDomain();
    final members = await listMembers(groupId);
    return detail.copyWith(
      memberCount: members.where((member) => member.leftAt == null).length,
      members: members,
    );
  }

  @override
  Future<List<GroupMember>> listMembers(String groupId) async {
    final body = await _get('/api/v1/groups/$groupId/members');
    return GroupMembersApiResponse.fromJson(body).toDomain();
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
    return GroupEnvelopeApiResponse.fromJson(body).toDomain();
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
    return GroupEnvelopeApiResponse.fromJson(body).toDomain();
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
  Future<void> leaveGroup(String groupId) async {
    await _send(
      () => _apiClient.dio.delete<Map<String, dynamic>>(
        '/api/v1/groups/$groupId/members/me',
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
    return GroupMemberEnvelopeApiResponse.fromJson(body).toDomain();
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
      throw groupApiExceptionFromDio(
        error,
        fallbackMessage: 'Grup işlemi tamamlanamadı. Lütfen tekrar deneyin.',
      );
    }
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
    return DebtSummaryApiResponse.fromJson(body).toDomain();
  }

  @override
  Future<List<Settlement>> listSettlements(String groupId) async {
    final body = await _get('/api/v1/groups/$groupId/settlements');
    return SettlementsApiResponse.fromJson(body).toDomain();
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

    return SettlementEnvelopeApiResponse.fromJson(body).toDomain();
  }

  @override
  Future<void> createInvitation({
    required String groupId,
    required String email,
    GroupRole role = GroupRole.member,
  }) async {
    await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/groups/$groupId/invitations',
        data: {'email': email, 'role': role.name},
      ),
    );
  }

  @override
  Future<GroupMember> acceptInvitation(String token) async {
    final encodedToken = Uri.encodeComponent(token);
    final body = await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/group-invitations/$encodedToken/accept',
      ),
    );
    return GroupMemberEnvelopeApiResponse.fromJson(body).toDomain();
  }

  @override
  Future<List<PendingGroupInvitation>> listPendingInvitations() async {
    final body = await _send(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/api/v1/groups/invitations/pending',
      ),
    );
    return PendingGroupInvitationsResponse.fromJson(body).invitations;
  }

  @override
  Future<GroupMember> acceptInvitationById(String invitationId) async {
    final body = await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/groups/invitations/$invitationId/accept',
      ),
    );
    return GroupMemberEnvelopeApiResponse.fromJson(body).toDomain();
  }

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
