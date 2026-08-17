import 'dart:async';
import 'dart:math';

import 'package:finance_database/finance_database.dart' hide SyncState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/storage/installation_id_provider.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../data/pending_task_sync_gateway.dart';
import '../domain/sync_state.dart';

typedef Delay = Future<void> Function(Duration duration);
typedef Clock = DateTime Function();

abstract interface class SyncTaskRepository {
  Future<List<OfflineTask>> getPendingTasks({int limit = 50});
  Future<Set<Id>> requeueFailedAndConflicted();
  Future<void> markAsSynced(Id id);
  Future<void> updateTaskError(Id id, String error);
  Future<void> markPermanentlyFailed(Id id, String error);
  Future<void> markConflict(Id id, String error);
  Future<int> deleteSyncedBefore(DateTime cutoff, {int limit = 100});
}

class IsarSyncTaskRepository implements SyncTaskRepository {
  const IsarSyncTaskRepository(this.repository);

  final OfflineTaskRepository repository;

  @override
  Future<List<OfflineTask>> getPendingTasks({int limit = 50}) =>
      repository.getPendingPersonalTasks(limit: limit);

  @override
  Future<Set<Id>> requeueFailedAndConflicted() =>
      repository.requeueFailedAndConflictedPersonalTasks();

  @override
  Future<void> markAsSynced(Id id) => repository.markAsSynced(id);

  @override
  Future<void> updateTaskError(Id id, String error) =>
      repository.updateTaskError(id, error);

  @override
  Future<void> markPermanentlyFailed(Id id, String error) =>
      repository.markPermanentlyFailed(id, error);

  @override
  Future<void> markConflict(Id id, String error) =>
      repository.markConflict(id, error);

  @override
  Future<int> deleteSyncedBefore(DateTime cutoff, {int limit = 100}) =>
      repository.deleteSyncedBefore(cutoff, limit: limit);
}

final installationIdProvider = Provider<InstallationIdProvider>(
  (ref) => PersistentInstallationIdProvider(),
);

final pendingTaskSyncGatewayProvider = Provider<PendingTaskSyncGateway>(
  (ref) => DioPendingTaskSyncGateway(
    apiClient: ref.watch(apiClientProvider),
    installationIdProvider: ref.watch(installationIdProvider),
  ),
);

final syncTaskRepositoryProvider = Provider<SyncTaskRepository>(
  (ref) => IsarSyncTaskRepository(ref.watch(offlineTaskRepositoryProvider)),
);

final syncCoordinatorProvider = NotifierProvider<SyncCoordinator, SyncState>(
  SyncCoordinator.new,
);

class SyncCoordinator extends Notifier<SyncState> {
  SyncCoordinator({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 1),
    Random? random,
    Delay? delay,
    Clock? clock,
  }) : _random = random ?? Random.secure(),
       _delay = delay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  static const batchSize = 50;
  static const syncedRetention = Duration(days: 7);
  static const cleanupBatchSize = 100;

  final int maxRetries;
  final Duration initialDelay;
  final Random _random;
  final Delay _delay;
  final Clock _clock;
  Future<void>? _activeSync;
  bool _rerunRequested = false;
  bool _retryRequested = false;

  @override
  SyncState build() => const SyncState();

  Future<void> syncPendingTasks() =>
      _startSync(requeueRetryable: false, rerunIfActive: false);

  Future<void> syncAfterSave() =>
      _startSync(requeueRetryable: false, rerunIfActive: true);

  Future<void> retryFailedAndConflicted() =>
      _startSync(requeueRetryable: true, rerunIfActive: true);

  Future<void> _startSync({
    required bool requeueRetryable,
    required bool rerunIfActive,
  }) {
    final running = _activeSync;
    if (running != null) {
      if (rerunIfActive || requeueRetryable) {
        _rerunRequested = true;
        _retryRequested = _retryRequested || requeueRetryable;
      }
      return running;
    }

    _rerunRequested = true;
    _retryRequested = _retryRequested || requeueRetryable;

    late final Future<void> operation;
    operation = _drainSyncRequests().whenComplete(() {
      if (identical(_activeSync, operation)) {
        _activeSync = null;
      }
    });
    _activeSync = operation;
    return operation;
  }

  Future<void> _drainSyncRequests() async {
    while (_rerunRequested) {
      _rerunRequested = false;
      final shouldRequeueRetryable = _retryRequested;
      _retryRequested = false;

      await _runSyncSafely(requeueRetryable: shouldRequeueRetryable);
    }
  }

  Future<void> _runSyncSafely({required bool requeueRetryable}) async {
    try {
      final freshRetryTaskIds = requeueRetryable
          ? await ref
                .read(syncTaskRepositoryProvider)
                .requeueFailedAndConflicted()
          : const <Id>{};
      await _sync(freshRetryTaskIds: freshRetryTaskIds);
    } on Object catch (error) {
      state = SyncState(
        status: SyncStatus.error,
        completedCount: state.completedCount,
        totalCount: state.totalCount,
        conflictCount: state.conflictCount,
        errorMessage: 'Senkronizasyon başlatılamadı: ${_safeError(error)}',
      );
    }
  }

  Future<void> _sync({Set<Id> freshRetryTaskIds = const <Id>{}}) async {
    final repository = ref.read(syncTaskRepositoryProvider);
    final gateway = ref.read(pendingTaskSyncGatewayProvider);
    var completed = 0;
    var total = 0;
    var conflictCount = 0;
    final failures = <String>[];
    state = const SyncState(status: SyncStatus.syncing);

    while (true) {
      final tasks = await repository.getPendingTasks(limit: batchSize);
      if (tasks.isEmpty) break;
      total += tasks.length;

      for (final task in tasks) {
        final outcome = await _sendWithRetry(
          task,
          repository,
          gateway,
          freshRetryBudget: freshRetryTaskIds.contains(task.id),
        );
        switch (outcome) {
          case _TaskSuccess():
            break;
          case _TaskConflict():
            conflictCount += 1;
          case _TaskFailure(:final message):
            failures.add(message);
        }
        completed += 1;
        state = SyncState(
          status: SyncStatus.syncing,
          completedCount: completed,
          totalCount: total,
          conflictCount: conflictCount,
        );
      }
    }

    await _cleanupSynced(repository);
    final status = failures.isNotEmpty
        ? SyncStatus.error
        : conflictCount > 0
        ? SyncStatus.conflict
        : SyncStatus.success;
    final message = failures.isNotEmpty
        ? '${failures.length} işlem senkronize edilemedi: ${failures.first}'
        : conflictCount > 0
        ? '$conflictCount işlemde sunucu çakışması oluştu.'
        : null;
    state = SyncState(
      status: status,
      completedCount: completed,
      totalCount: total,
      conflictCount: conflictCount,
      errorMessage: message,
    );
  }

  Future<_TaskOutcome> _sendWithRetry(
    OfflineTask task,
    SyncTaskRepository repository,
    PendingTaskSyncGateway gateway, {
    required bool freshRetryBudget,
  }) async {
    // Manuel retry'da kalıcı retryCount audit için korunur; bu çalıştırmaya
    // ayrı ve taze bir deneme bütçesi verilir.
    var attempt = freshRetryBudget ? 0 : task.retryCount;
    while (attempt < maxRetries) {
      try {
        await gateway.send(task);
        await repository.markAsSynced(task.id);
        return const _TaskSuccess();
      } on Object catch (error) {
        final message = _safeError(error);
        if (error is SyncConflictException) {
          await repository.markConflict(task.id, message);
          return const _TaskConflict();
        }
        if (isUnrecoverableSyncError(error)) {
          await repository.markPermanentlyFailed(task.id, message);
          return _TaskFailure(message);
        }

        attempt += 1;
        await repository.updateTaskError(task.id, message);
        if (attempt >= maxRetries) {
          await repository.markPermanentlyFailed(task.id, message);
          return _TaskFailure(message);
        }
        await _delay(_backoff(attempt));
      }
    }

    const message = 'Maksimum yeniden deneme sayısına ulaşıldı.';
    await repository.markPermanentlyFailed(task.id, message);
    return const _TaskFailure(message);
  }

  Future<void> _cleanupSynced(SyncTaskRepository repository) async {
    final cutoff = _clock().subtract(syncedRetention);
    int deleted;
    do {
      deleted = await repository.deleteSyncedBefore(
        cutoff,
        limit: cleanupBatchSize,
      );
    } while (deleted == cleanupBatchSize);
  }

  Duration _backoff(int attempt) {
    final exponentialMs = initialDelay.inMilliseconds * pow(2, attempt - 1);
    final jitterMs = _random.nextInt(max(1, initialDelay.inMilliseconds + 1));
    return Duration(milliseconds: exponentialMs.toInt() + jitterMs);
  }

  String _safeError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

sealed class _TaskOutcome {
  const _TaskOutcome();
}

final class _TaskSuccess extends _TaskOutcome {
  const _TaskSuccess();
}

final class _TaskConflict extends _TaskOutcome {
  const _TaskConflict();
}

final class _TaskFailure extends _TaskOutcome {
  const _TaskFailure(this.message);

  final String message;
}
