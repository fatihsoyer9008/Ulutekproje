import 'dart:async';
import 'dart:math';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/storage/installation_id_provider.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../data/pending_task_sync_gateway.dart';
import '../domain/sync_state.dart';

typedef Delay = Future<void> Function(Duration duration);

final installationIdProvider = Provider<InstallationIdProvider>(
  (ref) => PersistentInstallationIdProvider(),
);

final pendingTaskSyncGatewayProvider = Provider<PendingTaskSyncGateway>(
  (ref) => DioPendingTaskSyncGateway(
    apiClient: ref.watch(apiClientProvider),
    installationIdProvider: ref.watch(installationIdProvider),
  ),
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
  }) : _random = random ?? Random.secure(),
       _delay = delay ?? Future<void>.delayed;

  final int maxRetries;
  final Duration initialDelay;
  final Random _random;
  final Delay _delay;
  Future<void>? _activeSync;

  @override
  SyncState build() => const SyncState();

  Future<void> syncPendingTasks() {
    final running = _activeSync;
    if (running != null) return running;

    final operation = _runSyncSafely();
    _activeSync = operation;
    return operation.whenComplete(() {
      if (identical(_activeSync, operation)) _activeSync = null;
    });
  }

  Future<void> _runSyncSafely() async {
    try {
      await _sync();
    } on Object catch (error) {
      state = SyncState(
        status: SyncStatus.error,
        completedCount: state.completedCount,
        totalCount: state.totalCount,
        errorMessage: 'Senkronizasyon başlatılamadı: ${_safeError(error)}',
      );
    }
  }

  Future<void> _sync() async {
    final repository = ref.read(offlineTaskRepositoryProvider);
    final gateway = ref.read(pendingTaskSyncGatewayProvider);
    final tasks = await repository.getPendingTasks();
    state = SyncState(status: SyncStatus.syncing, totalCount: tasks.length);

    var completed = 0;
    final failures = <String>[];
    for (final task in tasks) {
      final error = await _sendWithRetry(task, repository, gateway);
      if (error != null) failures.add(error);
      completed += 1;
      state = SyncState(
        status: SyncStatus.syncing,
        completedCount: completed,
        totalCount: tasks.length,
      );
    }

    state = SyncState(
      status: failures.isEmpty ? SyncStatus.success : SyncStatus.error,
      completedCount: completed,
      totalCount: tasks.length,
      errorMessage: failures.isEmpty
          ? null
          : '${failures.length} işlem senkronize edilemedi: ${failures.first}',
    );
  }

  Future<String?> _sendWithRetry(
    OfflineTask task,
    OfflineTaskRepository repository,
    PendingTaskSyncGateway gateway,
  ) async {
    var attempt = task.retryCount;
    while (attempt < maxRetries) {
      try {
        await gateway.send(task);
        await repository.markAsSynced(task.id);
        return null;
      } on Object catch (error) {
        final message = _safeError(error);
        if (isUnrecoverableSyncError(error)) {
          await repository.markPermanentlyFailed(task.id, message);
          return message;
        }

        attempt += 1;
        await repository.updateTaskError(task.id, message);
        if (attempt >= maxRetries) {
          await repository.markPermanentlyFailed(task.id, message);
          return message;
        }
        await _delay(_backoff(attempt));
      }
    }

    const message = 'Maksimum yeniden deneme sayısına ulaşıldı.';
    await repository.markPermanentlyFailed(task.id, message);
    return message;
  }

  Duration _backoff(int attempt) {
    final exponentialMs = initialDelay.inMilliseconds * pow(2, attempt - 1);
    final jitterMs = _random.nextInt(max(1, initialDelay.inMilliseconds + 1));
    return Duration(milliseconds: exponentialMs.toInt() + jitterMs);
  }

  String _safeError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}
