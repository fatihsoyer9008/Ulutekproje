import '../domain/group_models.dart';

abstract interface class GroupExpenseRepository {
  Future<List<GroupExpense>> listExpenses(String groupId);

  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  });

  Future<GroupExpense> createExpense(
    GroupExpense expense, {
    required String idempotencyKey,
  });
}

abstract interface class DebtSummaryRepository {
  Future<DebtSummary> getDebtSummary(String groupId);
}

abstract interface class GroupRepository
    implements GroupExpenseRepository, DebtSummaryRepository {
  Future<GroupsResponse> listGroups({bool includeArchived = false});

  Future<GroupDetail> getGroup(String groupId);

  Future<GroupDetail> createGroup({
    required String name,
    String? description,
    String currency = 'TRY',
  });

  Future<GroupDetail> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool clearDescription = false,
  });

  Future<void> archiveGroup(String groupId);

  Future<GroupMember> addMember({
    required String groupId,
    required String userId,
    required String displayName,
    GroupRole role = GroupRole.member,
  });

  Future<void> removeMember({required String groupId, required String userId});

  Future<List<Settlement>> listSettlements(String groupId);

  Future<Settlement> createSettlement(
    Settlement settlement, {
    required String idempotencyKey,
  });
}
