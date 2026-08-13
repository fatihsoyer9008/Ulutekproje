import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../domain/group_models.dart';
import 'demo_group_seed.dart';
import 'fake_group_repository.dart';

final fakeGroupRepositoryProvider = Provider<FakeGroupRepository>((ref) {
  final user = ref.watch(authSessionControllerProvider).user;
  final currentUserId =
      user?.id ??
      const String.fromEnvironment(
        'DEMO_GROUP_USER_ID',
        defaultValue: '00000000-0000-4000-8000-000000000001',
      );
  final currentUserDisplayName = user?.displayName?.trim().isNotEmpty == true
      ? user!.displayName!.trim()
      : (user?.email ?? 'Demo Kullanıcı');
  final seed = createDemoGroupSeed(
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
  );

  return FakeGroupRepository(
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    groups: seed.groups,
    expensesByGroup: seed.expensesByGroup,
    debtSummariesByGroup: seed.debtSummariesByGroup,
  );
});

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
