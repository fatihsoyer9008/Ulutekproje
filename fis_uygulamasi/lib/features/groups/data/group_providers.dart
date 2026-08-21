import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/network/request_id.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../../sync/application/automatic_sync_service.dart';
import '../application/group_expense_conflict_service.dart';
import '../application/local_first_group_expense_reader.dart';
import '../application/offline_first_group_expense_mutator.dart';
import '../application/offline_first_group_expense_writer.dart';
import '../domain/group_activity_models.dart';
import '../domain/group_models.dart';
import 'api_group_activity_repository.dart';
import 'api_group_repository.dart';
import 'demo_group_activity_repository.dart';
import 'demo_group_seed.dart';
import 'fake_group_repository.dart';
import 'group_activity_repository.dart';

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

final apiGroupActivityRepositoryProvider = Provider<GroupActivityRepository>(
  (ref) => ApiGroupActivityRepository(
    ref.watch(apiClientProvider),
    currentUserId: ref.watch(currentGroupUserIdProvider),
  ),
);

final demoGroupActivityRepositoryProvider = Provider<GroupActivityRepository>(
  (ref) => DemoGroupActivityRepository(),
);

final groupActivityRepositoryProvider = Provider<GroupActivityRepository>((
  ref,
) {
  final groupRepository = ref.watch(groupRepositoryProvider);
  if (ref.watch(groupMockModeProvider) ||
      groupRepository is FakeGroupRepository) {
    return ref.watch(demoGroupActivityRepositoryProvider);
  }
  return ref.watch(apiGroupActivityRepositoryProvider);
});

final groupActivityFeedProvider = FutureProvider<List<GroupActivityEntry>>(
  (ref) => loadAllGroupActivity(ref.watch(groupActivityRepositoryProvider)),
);

final groupExpenseRepositoryProvider = Provider<GroupExpenseRepository>(
  (ref) => ref.watch(groupRepositoryProvider),
);

final groupExpenseLocalFirstListingEnabledProvider = Provider<bool>(
  (ref) =>
      !ref.watch(groupMockModeProvider) &&
      ref.watch(groupExpenseRepositoryProvider) is ApiGroupRepository,
);

final localFirstGroupExpenseReaderProvider =
    Provider<LocalFirstGroupExpenseReader>(
      (ref) => LocalFirstGroupExpenseReader(
        ref.watch(groupExpenseOfflineRepositoryProvider),
        ref.watch(groupExpenseRepositoryProvider),
      ),
    );

final offlineFirstGroupExpenseWriterProvider =
    Provider<OfflineFirstGroupExpenseWriter>(
      (ref) => OfflineFirstGroupExpenseWriter(
        ref.watch(groupExpenseOfflineRepositoryProvider),
        triggerSynchronization: () {
          unawaited(
            ref.read(automaticSyncServiceProvider).syncGroupAfterSave(),
          );
        },
      ),
    );

final offlineFirstGroupExpenseMutatorProvider =
    Provider<OfflineFirstGroupExpenseMutator>(
      (ref) => OfflineFirstGroupExpenseMutator(
        ref.watch(groupExpenseOfflineRepositoryProvider),
        ref.watch(offlineFirstGroupExpenseWriterProvider),
      ),
    );

final groupExpenseConflictServiceProvider =
    Provider<GroupExpenseConflictResolver>(
      (ref) => GroupExpenseConflictService(
        ref.watch(groupExpenseOfflineRepositoryProvider),
        ref.watch(groupExpenseRepositoryProvider),
        newUuidV4,
        () => ref.read(automaticSyncServiceProvider).syncGroupAfterSave(),
      ),
    );

final groupExpenseConflictsProvider =
    StreamProvider<List<GroupExpenseConflict>>((ref) {
      final userId = ref.watch(currentGroupUserIdProvider);
      if (userId == null) {
        return Stream.value(const <GroupExpenseConflict>[]);
      }
      return ref
          .watch(groupExpenseConflictServiceProvider)
          .watch(ownerKey: 'user:$userId');
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

final groupExpensesProvider = StreamProvider.family<List<GroupExpense>, String>(
  (ref, groupId) {
    final remote = ref.watch(groupExpenseRepositoryProvider);
    final userId = ref.watch(currentGroupUserIdProvider);
    if (!ref.watch(groupExpenseLocalFirstListingEnabledProvider) ||
        userId == null) {
      return Stream.fromFuture(remote.listExpenses(groupId));
    }

    final ownerKey = 'user:$userId';
    final reader = ref.watch(localFirstGroupExpenseReaderProvider);
    unawaited(
      reader
          .refresh(groupId: groupId, ownerKey: ownerKey)
          .then<void>((_) {})
          .catchError((Object _) {}),
    );
    return reader.watch(groupId: groupId, ownerKey: ownerKey);
  },
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
