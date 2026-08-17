import 'dart:async';
import 'dart:math';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../core/database/database_providers.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../data/group_offline_operation_mapper.dart';
import '../data/group_sync_gateway.dart';
import '../domain/group_offline_operation.dart';
import '../domain/group_sync_state.dart';

typedef GroupSyncDelay = Future<void> Function(Duration duration);

abstract interface class GroupSyncTaskRepository {
  Future<List<OfflineTask>> getPendingTasks({int limit = 50});
  Future<Set<Id>> requeueFailedAndConflicted();
  Future<void> markAsSynced(Id id);
  Future<void> recordRetryableError(Id id, String error);
  Future<void> markPermanentlyFailed(Id id, String error);
  Future<void> markConflict(Id id, String error);
  Future<int> applyPulledChanges(List<GroupPullChange> changes);
}

class IsarGroupSyncTaskRepository implements GroupSyncTaskRepository {
  const IsarGroupSyncTaskRepository(this.repository, this.ownerKey);

  final GroupExpenseOfflineRepository repository;
  final String ownerKey;

  @override
  Future<List<OfflineTask>> getPendingTasks({int limit = 50}) =>
      repository.getPendingSyncTasks(ownerKey: ownerKey, limit: limit);

  @override
  Future<Set<Id>> requeueFailedAndConflicted() =>
      repository.requeueFailedAndConflictedSyncTasks();

  @override
  Future<void> markAsSynced(Id id) => repository.markSyncTaskAsSynced(id);

  @override
  Future<void> recordRetryableError(Id id, String error) =>
      repository.recordSyncTaskError(id, error);

  @override
  Future<void> markPermanentlyFailed(Id id, String error) =>
      repository.markSyncTaskFailed(id, error);

  @override
  Future<void> markConflict(Id id, String error) =>
      repository.markSyncTaskConflict(id, error);

  @override
  Future<int> applyPulledChanges(List<GroupPullChange> changes) async {
    var applied = 0;
    for (final change in changes) {
      final operation = GroupOfflineOperation.fromJson(change.operation);
      // ExpenseShare ve Settlement için ayrı yerel persistence modelleri henüz
      // bulunmadığından yalnız GroupExpense snapshot/tombstone uygulanır.
      if (operation is! GroupExpenseOfflineOperation) {
        continue;
      }
      if (operation.type == GroupOfflineOperationType.groupExpenseDelete) {
        if (await repository.applyPulledTombstone(
          expenseId: operation.expenseId,
          groupId: operation.groupId,
          ownerKey: operation.ownerKey,
          deletedAt: change.serverUpdatedAt,
        )) {
          applied += 1;
        }
        continue;
      }
      final entity = operation.toGroupExpenseEntity()
        ..syncState = SyncState.synced;
      if (await repository.saveSyncedFromPull(entity)) applied += 1;
    }
    return applied;
  }
}

final fakeGroupSyncServerProvider = Provider<FakeGroupSyncServer>(
  (ref) => FakeGroupSyncServer(),
);

final groupPushGatewayProvider = Provider<GroupPushGateway>(
  (ref) =>
      ref.watch(groupMockModeForSyncProvider) ||
          ref.watch(authSessionControllerProvider).user == null
      ? FakeGroupPushGateway(ref.watch(fakeGroupSyncServerProvider))
      : DioGroupPushGateway(ref.watch(apiClientProvider).dio),
);

final groupPullGatewayProvider = Provider<GroupPullGateway>(
  (ref) =>
      ref.watch(groupMockModeForSyncProvider) ||
          ref.watch(authSessionControllerProvider).user == null
      ? FakeGroupPullGateway(ref.watch(fakeGroupSyncServerProvider))
      : DioGroupPullGateway(ref.watch(apiClientProvider).dio),
);

final groupMockModeForSyncProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('GROUP_MOCK_MODE'),
);

final groupSyncTaskRepositoryProvider = Provider<GroupSyncTaskRepository>((
  ref,
) {
  final userId = ref.watch(authSessionControllerProvider).user?.id;
  return IsarGroupSyncTaskRepository(
    ref.watch(groupExpenseOfflineRepositoryProvider),
    userId == null ? 'guest:no-session' : 'user:$userId',
  );
});

final groupSyncCoordinatorProvider =
    NotifierProvider<GroupSyncCoordinator, GroupSyncState>(
      GroupSyncCoordinator.new,
    );

class GroupSyncCoordinator extends Notifier<GroupSyncState> {
  GroupSyncCoordinator({
    this.maxRetries = 5,
    this.initialBackoff = const Duration(seconds: 1),
    GroupSyncDelay? delay,
  }) : assert(maxRetries > 0),
       assert(!initialBackoff.isNegative),
       _delay = delay ?? Future<void>.delayed;

  static const batchSize = 50;

  final int maxRetries;
  final Duration initialBackoff;
  final GroupSyncDelay _delay;
  Future<void>? _activeSync;
  bool _rerunRequested = false;
  bool _manualRetryRequested = false;
  String? _pullCursor;

  @override
  GroupSyncState build() => const GroupSyncState();

  Future<void> syncPendingAndPull() =>
      _startSync(manualRetry: false, rerunIfActive: false);

  Future<void> syncAfterSave() =>
      _startSync(manualRetry: false, rerunIfActive: true);

  Future<void> retryFailedAndConflicted() =>
      _startSync(manualRetry: true, rerunIfActive: true);

  Future<void> manualRetry() => retryFailedAndConflicted();

  Future<void> _startSync({
    required bool manualRetry,
    required bool rerunIfActive,
  }) {
    final running = _activeSync;
    if (running != null) {
      if (rerunIfActive || manualRetry) {
        _rerunRequested = true;
        _manualRetryRequested = _manualRetryRequested || manualRetry;
      }
      return running;
    }

    _rerunRequested = true;
    _manualRetryRequested = _manualRetryRequested || manualRetry;
    late final Future<void> operation;
    operation = _drainRequests().whenComplete(() {
      if (identical(_activeSync, operation)) _activeSync = null;
    });
    _activeSync = operation;
    return operation;
  }

  Future<void> _drainRequests() async {
    while (_rerunRequested) {
      _rerunRequested = false;
      final manualRetry = _manualRetryRequested;
      _manualRetryRequested = false;
      await _runSafely(manualRetry: manualRetry);
    }
  }

  Future<void> _runSafely({required bool manualRetry}) async {
    try {
      final repository = ref.read(groupSyncTaskRepositoryProvider);
      final freshRetryIds = manualRetry
          ? await repository.requeueFailedAndConflicted()
          : const <Id>{};
      await _sync(repository, freshRetryIds: freshRetryIds);
    } on Object catch (error) {
      state = GroupSyncState(
        status: GroupSyncStatus.failed,
        completedCount: state.completedCount,
        totalCount: state.totalCount,
        failedCount: max(1, state.failedCount),
        conflictCount: state.conflictCount,
        pulledCount: state.pulledCount,
        errorMessage: 'Grup senkronizasyonu başlatılamadı: ${_safe(error)}',
      );
    }
  }

  Future<void> _sync(
    GroupSyncTaskRepository repository, {
    required Set<Id> freshRetryIds,
  }) async {
    final pushGateway = ref.read(groupPushGatewayProvider);
    final pullGateway = ref.read(groupPullGatewayProvider);
    var completed = 0;
    var total = 0;
    var failed = 0;
    var conflicts = 0;
    var pulled = 0;
    final failureMessages = <String>[];

    var tasks = await repository.getPendingTasks(limit: batchSize);
    if (tasks.isNotEmpty) {
      state = GroupSyncState(
        status: GroupSyncStatus.pending,
        pendingCount: tasks.length,
        totalCount: tasks.length,
      );
    }
    state = GroupSyncState(
      status: GroupSyncStatus.syncing,
      pendingCount: tasks.length,
      totalCount: tasks.length,
    );

    while (tasks.isNotEmpty) {
      total += tasks.length;
      for (final task in tasks) {
        final outcome = await _pushWithRetry(
          task,
          repository,
          pushGateway,
          freshRetryBudget: freshRetryIds.contains(task.id),
        );
        switch (outcome) {
          case _GroupTaskSuccess():
            break;
          case _GroupTaskConflict():
            conflicts += 1;
          case _GroupTaskFailure(:final message):
            failed += 1;
            failureMessages.add(message);
        }
        completed += 1;
        state = GroupSyncState(
          status: GroupSyncStatus.syncing,
          completedCount: completed,
          totalCount: total,
          failedCount: failed,
          conflictCount: conflicts,
          pulledCount: pulled,
        );
      }
      tasks = await repository.getPendingTasks(limit: batchSize);
    }

    var hasMore = true;
    final seenCursors = <String?>{};
    while (hasMore) {
      if (!seenCursors.add(_pullCursor)) {
        throw StateError('Fake group pull cursor ilerlemiyor.');
      }
      final batch = await pullGateway.pull(cursor: _pullCursor);
      final appliedCount = await repository.applyPulledChanges(batch.changes);
      pulled += appliedCount;
      if (batch.nextCursor != null) _pullCursor = batch.nextCursor;
      hasMore = batch.hasMore;
      state = GroupSyncState(
        status: GroupSyncStatus.syncing,
        completedCount: completed,
        totalCount: total,
        failedCount: failed,
        conflictCount: conflicts,
        pulledCount: pulled,
      );
    }

    final status = failed > 0
        ? GroupSyncStatus.failed
        : conflicts > 0
        ? GroupSyncStatus.conflict
        : GroupSyncStatus.success;
    state = GroupSyncState(
      status: status,
      completedCount: completed,
      totalCount: total,
      failedCount: failed,
      conflictCount: conflicts,
      pulledCount: pulled,
      errorMessage: failed > 0
          ? '$failed grup işlemi senkronize edilemedi: '
                '${failureMessages.first}'
          : conflicts > 0
          ? '$conflicts grup işleminde sunucu çakışması oluştu.'
          : null,
    );
  }

  Future<_GroupTaskOutcome> _pushWithRetry(
    OfflineTask task,
    GroupSyncTaskRepository repository,
    GroupPushGateway gateway, {
    required bool freshRetryBudget,
  }) async {
    var attempt = freshRetryBudget ? 0 : task.retryCount;
    while (attempt < maxRetries) {
      try {
        final result = await gateway.push(task);
        if (result.operationId != task.clientTaskId) {
          throw const GroupSyncPermanentException(
            'Push sonucu farklı bir grup operasyonuna ait.',
          );
        }
        if (result.status == GroupPushStatus.conflict) {
          final message = result.message ?? 'Grup operasyonu çakıştı.';
          await repository.markConflict(task.id, message);
          return const _GroupTaskConflict();
        }
        await repository.markAsSynced(task.id);
        return const _GroupTaskSuccess();
      } on Object catch (error) {
        final message = _safe(error);
        if (_isPermanent(error)) {
          await repository.markPermanentlyFailed(task.id, message);
          return _GroupTaskFailure(message);
        }
        attempt += 1;
        await repository.recordRetryableError(task.id, message);
        if (attempt >= maxRetries) {
          await repository.markPermanentlyFailed(task.id, message);
          return _GroupTaskFailure(message);
        }
        await _delay(_backoff(attempt));
      }
    }

    const message = 'Maksimum grup sync deneme sayısına ulaşıldı.';
    await repository.markPermanentlyFailed(task.id, message);
    return const _GroupTaskFailure(message);
  }

  Duration _backoff(int attempt) => Duration(
    milliseconds: initialBackoff.inMilliseconds * pow(2, attempt - 1).toInt(),
  );

  bool _isPermanent(Object error) =>
      error is FormatException || error is GroupSyncPermanentException;

  String _safe(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

sealed class _GroupTaskOutcome {
  const _GroupTaskOutcome();
}

final class _GroupTaskSuccess extends _GroupTaskOutcome {
  const _GroupTaskSuccess();
}

final class _GroupTaskConflict extends _GroupTaskOutcome {
  const _GroupTaskConflict();
}

final class _GroupTaskFailure extends _GroupTaskOutcome {
  const _GroupTaskFailure(this.message);

  final String message;
}
