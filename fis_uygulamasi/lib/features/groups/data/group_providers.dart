import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/group_models.dart';
import 'fake_group_repository.dart';

final fakeGroupRepositoryProvider = Provider<FakeGroupRepository>(
  (ref) => FakeGroupRepository(),
);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => ref.watch(fakeGroupRepositoryProvider),
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
