import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../domain/group_models.dart';
import 'api_group_repository.dart';
import 'group_repository.dart';

final apiGroupRepositoryProvider = Provider<ApiGroupRepository>(
  (ref) => ApiGroupRepository(ref.watch(apiClientProvider)),
);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => ref.watch(apiGroupRepositoryProvider),
);

final groupExpenseRepositoryProvider = Provider<GroupExpenseRepository>(
  (ref) => ref.watch(groupRepositoryProvider),
);

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
