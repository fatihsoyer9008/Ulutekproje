import 'dart:async';
import 'dart:math';

import 'package:app_main/features/sync/application/sync_coordinator.dart';
import 'package:app_main/features/sync/data/pending_task_sync_gateway.dart';
import 'package:app_main/features/sync/domain/sync_state.dart';
import 'package:dio/dio.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  OfflineTask task(int id, {int retryCount = 0}) => OfflineTask()
    ..id = id
    ..clientTaskId = 'operation-$id'
    ..payloadJson = '{}'
    ..retryCount = retryCount
    ..createdAt = DateTime(2026)
    ..updatedAt = DateTime(2026);

  ProviderContainer container({
    required _FakeSyncTaskRepository repository,
    required PendingTaskSyncGateway gateway,
    int maxRetries = 3,
    List<Duration>? delays,
  }) {
    final result = ProviderContainer(
      overrides: [
        syncTaskRepositoryProvider.overrideWithValue(repository),
        pendingTaskSyncGatewayProvider.overrideWithValue(gateway),
        syncCoordinatorProvider.overrideWith(
          () => SyncCoordinator(
            maxRetries: maxRetries,
            initialDelay: const Duration(milliseconds: 100),
            random: Random(1),
            delay: (duration) async => delays?.add(duration),
            clock: () => DateTime.utc(2026, 8, 5),
          ),
        ),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  test('başarılı gönderimi synced işaretler', () async {
    final repository = _FakeSyncTaskRepository([task(1)]);
    final scope = container(
      repository: repository,
      gateway: _FakeGateway((_) async {}),
    );

    await scope.read(syncCoordinatorProvider.notifier).syncPendingTasks();

    expect(repository.syncedIds, [1]);
    expect(scope.read(syncCoordinatorProvider).status, SyncStatus.success);
  });

  test('geçici hatadan sonra backoff ile tekrar dener', () async {
    final repository = _FakeSyncTaskRepository([task(1)]);
    final delays = <Duration>[];
    var attempts = 0;
    final scope = container(
      repository: repository,
      delays: delays,
      gateway: _FakeGateway((_) async {
        attempts += 1;
        if (attempts == 1) throw Exception('temporary');
      }),
    );

    await scope.read(syncCoordinatorProvider.notifier).syncPendingTasks();

    expect(attempts, 2);
    expect(delays, hasLength(1));
    expect(
      delays.single,
      greaterThanOrEqualTo(const Duration(milliseconds: 100)),
    );
    expect(repository.errorUpdates, 1);
    expect(repository.syncedIds, [1]);
  });

  test('maksimum retry sonunda görevi failed işaretler', () async {
    final repository = _FakeSyncTaskRepository([task(1)]);
    var attempts = 0;
    final scope = container(
      repository: repository,
      gateway: _FakeGateway((_) async {
        attempts += 1;
        throw Exception('offline');
      }),
    );

    await scope.read(syncCoordinatorProvider.notifier).syncPendingTasks();

    expect(attempts, 3);
    expect(repository.failedIds, [1]);
    expect(scope.read(syncCoordinatorProvider).status, SyncStatus.error);
  });

  test('kalıcı 4xx hatasını retry etmez', () async {
    final failedTask = task(1);
    final repository = _FakeSyncTaskRepository([failedTask]);
    var attempts = 0;
    final scope = container(
      repository: repository,
      gateway: _FakeGateway((_) async {
        attempts += 1;
        final request = RequestOptions(path: '/api/v1/sync/push');
        throw DioException(
          requestOptions: request,
          response: Response<void>(requestOptions: request, statusCode: 422),
        );
      }),
    );

    await scope.read(syncCoordinatorProvider.notifier).syncPendingTasks();

    expect(attempts, 1);
    expect(repository.failedIds, [1]);
    expect(repository.errorUpdates, 0);
    expect(failedTask.lastError, 'permanent_failure');
  });

  final categorizedErrors = <String, Object>{
    'network_unavailable': DioException(
      requestOptions: RequestOptions(path: '/api/v1/sync/push'),
      type: DioExceptionType.connectionError,
      message: 'socket details must not persist',
    ),
    'timeout': DioException(
      requestOptions: RequestOptions(path: '/api/v1/sync/push'),
      type: DioExceptionType.receiveTimeout,
      message: 'timeout details must not persist',
    ),
    'invalid_payload': const FormatException(
      'payload details must not persist',
    ),
    'server_unavailable': DioException(
      requestOptions: RequestOptions(path: '/api/v1/sync/push'),
      type: DioExceptionType.badResponse,
      response: Response<void>(
        requestOptions: RequestOptions(path: '/api/v1/sync/push'),
        statusCode: 503,
      ),
    ),
  };

  for (final MapEntry(key: expectedCategory, value: error)
      in categorizedErrors.entries) {
    test('$expectedCategory audit kodu lastError alanında saklanır', () async {
      final failedTask = task(1);
      final repository = _FakeSyncTaskRepository([failedTask]);
      final scope = container(
        repository: repository,
        gateway: _FakeGateway((_) async => throw error),
        maxRetries: 1,
      );

      await scope.read(syncCoordinatorProvider.notifier).syncPendingTasks();

      final state = scope.read(syncCoordinatorProvider);
      expect(failedTask.lastError, expectedCategory);
      expect(failedTask.lastError, isNot(contains('details')));
      expect(
        state.errorMessage,
        '1 işlem senkronize edilemedi: '
        'İşlem senkronize edilemedi. Lütfen tekrar deneyin.',
      );
      expect(state.errorMessage, isNot(contains(expectedCategory)));
    });
  }

  test('HTTP 200 conflict sonucunu ayrı state olarak tutar', () async {
    final repository = _FakeSyncTaskRepository([task(1)]);
    final scope = container(
      repository: repository,
      gateway: _FakeGateway(
        (_) async => throw const SyncConflictException('conflict'),
      ),
    );

    await scope.read(syncCoordinatorProvider.notifier).syncPendingTasks();

    final state = scope.read(syncCoordinatorProvider);
    expect(state.status, SyncStatus.conflict);
    expect(state.conflictCount, 1);
    expect(repository.conflictIds, [1]);
    expect(repository.syncedIds, isEmpty);
  });

  for (final retryStatus in [
    OfflineTaskStatus.failed,
    OfflineTaskStatus.conflict,
  ]) {
    test(
      '$retryStatus manuel retry ile pending yapılıp gatewaye gönderilir',
      () async {
        final retryTask = task(1, retryCount: 5)
          ..status = retryStatus
          ..lastError = 'previous error';
        final repository = _FakeSyncTaskRepository([])..addRetryable(retryTask);
        final gateway = _FakeGateway((_) async {});
        final scope = container(repository: repository, gateway: gateway);

        await scope
            .read(syncCoordinatorProvider.notifier)
            .retryFailedAndConflicted();

        expect(repository.requeueCalls, 1);
        expect(gateway.calls, 1);
        expect(repository.syncedIds, [1]);
        expect(scope.read(syncCoordinatorProvider).status, SyncStatus.success);
      },
    );
  }

  test(
    'bağlantı geri gelince yalnız retryable failed kuyruğunu çalıştırır',
    () async {
      final retryTask = task(1, retryCount: 5)
        ..status = OfflineTaskStatus.failed
        ..lastError = 'offline';
      final repository = _FakeSyncTaskRepository([])..addRetryable(retryTask);
      final gateway = _FakeGateway((_) async {});
      final scope = container(repository: repository, gateway: gateway);

      await scope
          .read(syncCoordinatorProvider.notifier)
          .syncAfterConnectivityRestored();

      expect(repository.connectivityRequeueCalls, 1);
      expect(repository.requeueCalls, 0);
      expect(gateway.calls, 1);
      expect(repository.syncedIds, [1]);
    },
  );

  test('eş zamanlı çağrılar aynı gönderimi paylaşır', () async {
    final repository = _FakeSyncTaskRepository([task(1)]);
    final release = Completer<void>();
    var calls = 0;
    final scope = container(
      repository: repository,
      gateway: _FakeGateway((_) async {
        calls += 1;
        await release.future;
      }),
    );
    final coordinator = scope.read(syncCoordinatorProvider.notifier);

    final first = coordinator.syncPendingTasks();
    final second = coordinator.syncPendingTasks();
    await Future<void>.delayed(Duration.zero);
    release.complete();
    await Future.wait([first, second]);

    expect(calls, 1);
    expect(repository.syncedIds, [1]);
  });

  test(
    'aktif sync temizlenirken yeni kayıt için takip turu başlatır',
    () async {
      final cleanupStarted = Completer<void>();
      final cleanupRelease = Completer<void>();
      final repository = _FakeSyncTaskRepository([task(1)])
        ..cleanupStarted = cleanupStarted
        ..cleanupRelease = cleanupRelease;
      final gateway = _FakeGateway((_) async {});
      final scope = container(repository: repository, gateway: gateway);
      final coordinator = scope.read(syncCoordinatorProvider.notifier);

      final firstSync = coordinator.syncPendingTasks();
      await cleanupStarted.future;

      repository.addPending(task(2));
      final followUpSync = coordinator.syncAfterSave();

      cleanupRelease.complete();
      await Future.wait([firstSync, followUpSync]);

      expect(gateway.calls, 2);
      expect(repository.syncedIds, [1, 2]);
    },
  );

  test('50 üzerindeki görevleri kuyruk boşalana kadar batch işler', () async {
    final repository = _FakeSyncTaskRepository(
      List.generate(105, (index) => task(index + 1)),
    );
    final gateway = _FakeGateway((_) async {});
    final scope = container(repository: repository, gateway: gateway);

    await scope.read(syncCoordinatorProvider.notifier).syncPendingTasks();

    expect(gateway.calls, 105);
    expect(repository.requestedLimits, [50, 50, 50, 50]);
    expect(repository.syncedIds, hasLength(105));
    expect(scope.read(syncCoordinatorProvider).totalCount, 105);
  });

  test('her çalışmada yedi günden eski synced kayıtları temizler', () async {
    final repository = _FakeSyncTaskRepository([])
      ..cleanupResults.addAll([100, 2]);
    final scope = container(
      repository: repository,
      gateway: _FakeGateway((_) async {}),
    );

    await scope.read(syncCoordinatorProvider.notifier).syncPendingTasks();

    expect(repository.cleanupCutoffs, [
      DateTime.utc(2026, 7, 29),
      DateTime.utc(2026, 7, 29),
    ]);
  });
}

class _FakeGateway implements PendingTaskSyncGateway {
  _FakeGateway(this.handler);

  final Future<void> Function(OfflineTask task) handler;
  int calls = 0;

  @override
  Future<void> send(OfflineTask task) {
    calls += 1;
    return handler(task);
  }
}

class _FakeSyncTaskRepository implements SyncTaskRepository {
  _FakeSyncTaskRepository(List<OfflineTask> tasks)
    : _pending = {for (final task in tasks) task.id: task};

  final Map<Id, OfflineTask> _pending;
  final Map<Id, OfflineTask> _retryable = {};
  final syncedIds = <Id>[];
  final failedIds = <Id>[];
  final conflictIds = <Id>[];
  final requestedLimits = <int>[];
  final cleanupCutoffs = <DateTime>[];
  final cleanupResults = <int>[];
  int errorUpdates = 0;
  int requeueCalls = 0;
  int connectivityRequeueCalls = 0;
  Completer<void>? cleanupStarted;
  Completer<void>? cleanupRelease;

  void addPending(OfflineTask task) => _pending[task.id] = task;

  void addRetryable(OfflineTask task) => _retryable[task.id] = task;

  @override
  Future<List<OfflineTask>> getPendingTasks({int limit = 50}) async {
    requestedLimits.add(limit);
    return _pending.values.take(limit).toList();
  }

  @override
  Future<Set<Id>> requeueFailedAndConflicted() async {
    requeueCalls += 1;
    final ids = _retryable.keys.toSet();
    for (final task in _retryable.values) {
      task.status = OfflineTaskStatus.pending;
      _pending[task.id] = task;
    }
    _retryable.clear();
    return ids;
  }

  @override
  Future<Set<Id>> requeueRetryableFailures() async {
    connectivityRequeueCalls += 1;
    final ids = _retryable.keys.toSet();
    for (final task in _retryable.values) {
      task.status = OfflineTaskStatus.pending;
      _pending[task.id] = task;
    }
    _retryable.clear();
    return ids;
  }

  @override
  Future<void> markAsSynced(Id id) async {
    _pending.remove(id);
    syncedIds.add(id);
  }

  @override
  Future<void> markPermanentlyFailed(Id id, String error) async {
    final task = _pending.remove(id);
    if (task != null) task.lastError = error;
    failedIds.add(id);
  }

  @override
  Future<void> markConflict(Id id, String error) async {
    final task = _pending.remove(id);
    if (task != null) task.lastError = error;
    conflictIds.add(id);
  }

  @override
  Future<void> updateTaskError(Id id, String error) async {
    errorUpdates += 1;
    final task = _pending[id];
    if (task != null) {
      task
        ..retryCount += 1
        ..lastError = error;
    }
  }

  @override
  Future<int> deleteSyncedBefore(DateTime cutoff, {int limit = 100}) async {
    cleanupCutoffs.add(cutoff);

    final started = cleanupStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }

    final release = cleanupRelease;
    if (release != null) {
      await release.future;
    }

    return cleanupResults.isEmpty ? 0 : cleanupResults.removeAt(0);
  }
}
