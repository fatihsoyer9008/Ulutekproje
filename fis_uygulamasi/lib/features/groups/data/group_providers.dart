import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/group_models.dart';
import '../presentation/itemized_split_page.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../../sync/application/sync_coordinator.dart';
import '../../../core/database/database_providers.dart';
import 'api_group_expense_repository.dart';
import 'api_group_repository.dart';
import 'group_repository.dart';
import 'receipt_sync_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => ApiGroupRepository(ref.watch(apiClientProvider)),
);

final groupExpenseRepositoryProvider = Provider<GroupExpenseRepository>(
  (ref) => ApiGroupExpenseRepository(ref.watch(apiClientProvider)),
);

final receiptSyncRepositoryProvider = Provider<ReceiptSyncRepository>(
  (ref) => ReceiptSyncRepository(
    apiClient: ref.watch(apiClientProvider),
    installationIdProvider: ref.watch(installationIdProvider),
  ),
);

final latestItemizedReceiptProvider = FutureProvider<ItemizedSplitReceipt?>((
  ref,
) async {
  final transactions = await ref
      .watch(transactionRepositoryProvider)
      .getAllTransactions();
  return ref
      .watch(receiptSyncRepositoryProvider)
      .syncLatestReceipt(transactions);
});

final debtSummaryRepositoryProvider = Provider<DebtSummaryRepository>(
  (ref) => ref.watch(groupRepositoryProvider),
);

final groupsProvider = FutureProvider<GroupsResponse>(
  (ref) => ref.watch(groupRepositoryProvider).listGroups(),
);

final groupDetailProvider = FutureProvider.family<GroupDetail, String>(
  (ref, groupId) => ref.watch(groupRepositoryProvider).getGroup(groupId),
);

final groupExpensesProvider = FutureProvider.family<List<GroupExpense>, String>(
  (ref, groupId) =>
      ref.watch(groupExpenseRepositoryProvider).listExpenses(groupId),
);

final groupDebtSummaryProvider = FutureProvider.family<DebtSummary, String>(
  (ref, groupId) =>
      ref.watch(debtSummaryRepositoryProvider).getDebtSummary(groupId),
);

final groupSettlementsProvider =
    FutureProvider.family<List<Settlement>, String>(
      (ref, groupId) =>
          ref.watch(groupRepositoryProvider).listSettlements(groupId),
    );
