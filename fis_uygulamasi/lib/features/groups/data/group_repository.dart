import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_database/finance_database.dart';

import '../domain/group_models.dart';
import '../domain/group_expense_requests.dart';
import '../domain/prepared_group_receipt.dart';

abstract interface class GroupRepository {
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

  Future<List<GroupExpense>> listExpenses(String groupId);

  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  });

  Future<PreparedGroupReceipt> prepareReceiptForSharing(TransactionDraft draft);

  Future<GroupExpense> createExpense({
    required String groupId,
    required CreateGroupExpenseRequest request,
    required String idempotencyKey,
  });

  Future<DebtSummary> getDebtSummary(String groupId);

  Future<List<Settlement>> listSettlements(String groupId);

  Future<Settlement> createSettlement(
    Settlement settlement, {
    required String idempotencyKey,
  });
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  throw StateError('GroupRepository uygulama kökünde bağlanmalıdır.');
});

final currentGroupUserIdProvider = Provider<String>(
  (ref) => '00000000-0000-4000-8000-000000000001',
);

final groupsProvider = FutureProvider<GroupsResponse>(
  (ref) => ref.watch(groupRepositoryProvider).listGroups(),
);

final groupDetailProvider = FutureProvider.family<GroupDetail, String>(
  (ref, groupId) => ref.watch(groupRepositoryProvider).getGroup(groupId),
);

final groupExpensesProvider = FutureProvider.family<List<GroupExpense>, String>(
  (ref, groupId) => ref.watch(groupRepositoryProvider).listExpenses(groupId),
);

final groupDebtSummaryProvider = FutureProvider.family<DebtSummary, String>(
  (ref, groupId) => ref.watch(groupRepositoryProvider).getDebtSummary(groupId),
);

final groupSettlementsProvider =
    FutureProvider.family<List<Settlement>, String>(
      (ref, groupId) =>
          ref.watch(groupRepositoryProvider).listSettlements(groupId),
    );
