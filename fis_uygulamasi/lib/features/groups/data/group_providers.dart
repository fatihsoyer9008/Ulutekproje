import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../application/offline_first_group_expense_writer.dart';
import '../domain/group_models.dart';
import 'api_group_repository.dart';
import 'demo_group_seed.dart';
import 'fake_group_repository.dart';

final currentGroupUserIdProvider = Provider<String?>(
  (ref) => ref.watch(
    authSessionControllerProvider.select((state) => state.user?.id),
  ),
);

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

final apiGroupRepositoryProvider = Provider<ApiGroupRepository>(
  (ref) => ApiGroupRepository(ref.watch(apiClientProvider)),
);

/// Can be enabled for offline demos with `--dart-define=GROUP_MOCK_MODE=true`.
final groupMockModeProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('GROUP_MOCK_MODE'),
);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => ref.watch(groupMockModeProvider)
      ? ref.watch(fakeGroupRepositoryProvider)
      : ref.watch(apiGroupRepositoryProvider),
);

final groupExpenseRepositoryProvider = Provider<GroupExpenseRepository>(
  (ref) => ref.watch(groupRepositoryProvider),
);

final offlineFirstGroupExpenseWriterProvider =
    Provider<OfflineFirstGroupExpenseWriter>(
      (ref) => OfflineFirstGroupExpenseWriter(
        ref.watch(groupExpenseOfflineRepositoryProvider),
      ),
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
