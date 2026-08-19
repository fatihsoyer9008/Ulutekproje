import 'dart:async';
import 'dart:convert';

import 'package:app_main/features/groups/application/group_sync_coordinator.dart';
import 'package:app_main/features/groups/data/group_sync_gateway.dart';
import 'package:app_main/features/groups/domain/group_sync_state.dart';
import 'package:dio/dio.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  ProviderContainer container({
    required _MemoryGroupSyncRepository repository,
    required FakeGroupSyncServer server,
    int maxRetries = 3,
    List<Duration>? delays,
    GroupPushGateway? pushGateway,
  }) {
    final scope = ProviderContainer(
      overrides: [
        groupSyncTaskRepositoryProvider.overrideWithValue(repository),
        fakeGroupSyncServerProvider.overrideWithValue(server),
        if (pushGateway != null)
          groupPushGatewayProvider.overrideWithValue(pushGateway),
        groupSyncCoordinatorProvider.overrideWith(
          () => GroupSyncCoordinator(
            maxRetries: maxRetries,
            initialBackoff: const Duration(milliseconds: 100),
            delay: (duration) async => delays?.add(duration),
          ),
        ),
      ],
    );
    addTearDown(scope.dispose);
    return scope;
  }

  test(
    'Riverpod state pending, syncing ve success sırasını yayınlar',
    () async {
      final task = _task(1);
      final repository = _MemoryGroupSyncRepository([task]);
      final scope = container(
        repository: repository,
        server: FakeGroupSyncServer(),
      );
      final statuses = <GroupSyncStatus>[];
      scope.listen(
        groupSyncCoordinatorProvider,
        (_, next) => statuses.add(next.status),
        fireImmediately: true,
      );

      await scope
          .read(groupSyncCoordinatorProvider.notifier)
          .syncPendingAndPull();

      final state = scope.read(groupSyncCoordinatorProvider);
      expect(
        statuses,
        containsAllInOrder(<GroupSyncStatus>[
          GroupSyncStatus.idle,
          GroupSyncStatus.pending,
          GroupSyncStatus.syncing,
          GroupSyncStatus.success,
        ]),
      );
      expect(repository.syncedIds, <Id>[task.id]);
      expect(repository.appliedChanges, hasLength(1));
      expect(state.completedCount, 1);
      expect(state.pulledCount, 1);
    },
  );

  test('geçici hatalarda 100ms, 200ms exponential backoff uygular', () async {
    final task = _task(1);
    final repository = _MemoryGroupSyncRepository([task]);
    final server = FakeGroupSyncServer()
      ..enqueuePushOutcome(
        task.clientTaskId,
        FakeGroupPushOutcome.temporaryFailure,
      )
      ..enqueuePushOutcome(
        task.clientTaskId,
        FakeGroupPushOutcome.temporaryFailure,
      );
    final delays = <Duration>[];
    final scope = container(
      repository: repository,
      server: server,
      delays: delays,
    );

    await scope
        .read(groupSyncCoordinatorProvider.notifier)
        .syncPendingAndPull();

    expect(delays, <Duration>[
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 200),
    ]);
    expect(task.retryCount, 2);
    expect(task.lastError, 'server_unavailable');
    expect(
      scope.read(groupSyncCoordinatorProvider).errorMessage,
      isNot(contains('server_unavailable')),
    );
    expect(task.lastAttemptAt, isNotNull);
    expect(task.status, OfflineTaskStatus.synced);
  });

  test('maksimum denemeden sonra task ve provider failed olur', () async {
    final task = _task(1);
    final repository = _MemoryGroupSyncRepository([task]);
    final server = FakeGroupSyncServer();
    for (var attempt = 0; attempt < 3; attempt++) {
      server.enqueuePushOutcome(
        task.clientTaskId,
        FakeGroupPushOutcome.temporaryFailure,
      );
    }
    final scope = container(repository: repository, server: server);

    await scope
        .read(groupSyncCoordinatorProvider.notifier)
        .syncPendingAndPull();

    final state = scope.read(groupSyncCoordinatorProvider);
    expect(task.retryCount, 3);
    expect(task.status, OfflineTaskStatus.failed);
    expect(task.lastError, 'server_unavailable');
    expect(state.status, GroupSyncStatus.failed);
    expect(state.failedCount, 1);
  });

  final categorizedErrors = <String, Object>{
    'network_unavailable': DioException(
      requestOptions: RequestOptions(path: '/api/v1/sync/groups/push'),
      type: DioExceptionType.connectionError,
      message: 'raw network details',
    ),
    'timeout': DioException(
      requestOptions: RequestOptions(path: '/api/v1/sync/groups/push'),
      type: DioExceptionType.connectionTimeout,
      message: 'raw timeout details',
    ),
    'invalid_payload': const FormatException('raw payload details'),
    'server_unavailable': const GroupSyncTemporaryException(
      'raw server details',
    ),
    'permanent_failure': const GroupSyncPermanentException(
      'raw permanent details',
    ),
  };

  for (final MapEntry(key: expectedCategory, value: error)
      in categorizedErrors.entries) {
    test(
      'grup $expectedCategory audit kodunu lastError alanında saklar',
      () async {
        final failedTask = _task(1);
        final repository = _MemoryGroupSyncRepository([failedTask]);
        final scope = container(
          repository: repository,
          server: FakeGroupSyncServer(),
          maxRetries: 1,
          pushGateway: _ThrowingGroupPushGateway(error),
        );

        await scope
            .read(groupSyncCoordinatorProvider.notifier)
            .syncPendingAndPull();

        final state = scope.read(groupSyncCoordinatorProvider);
        expect(failedTask.lastError, expectedCategory);
        expect(failedTask.lastError, isNot(contains('raw')));
        expect(
          state.errorMessage,
          '1 grup işlemi senkronize edilemedi: '
          'Grup işlemi senkronize edilemedi. Lütfen tekrar deneyin.',
        );
        expect(state.errorMessage, isNot(contains(expectedCategory)));
      },
    );
  }

  test('conflict retry yapmadan ayrı provider state olarak korunur', () async {
    final task = _task(1);
    final repository = _MemoryGroupSyncRepository([task]);
    final server = FakeGroupSyncServer()
      ..enqueuePushOutcome(task.clientTaskId, FakeGroupPushOutcome.conflict);
    final delays = <Duration>[];
    final scope = container(
      repository: repository,
      server: server,
      delays: delays,
    );

    await scope
        .read(groupSyncCoordinatorProvider.notifier)
        .syncPendingAndPull();

    final state = scope.read(groupSyncCoordinatorProvider);
    expect(task.status, OfflineTaskStatus.conflict);
    expect(task.lastError, contains('güncel grup'));
    final conflictAudit = jsonDecode(task.lastError!) as Map<String, dynamic>;
    expect(conflictAudit['code'], 'version_mismatch');
    expect(conflictAudit['kind'], 'group_sync_conflict');
    expect(delays, isEmpty);
    expect(state.status, GroupSyncStatus.conflict);
    expect(state.conflictCount, 1);
  });

  for (final status in <OfflineTaskStatus>[
    OfflineTaskStatus.failed,
    OfflineTaskStatus.conflict,
  ]) {
    test('$status manuel retry ile audit korunarak gönderilir', () async {
      final previousAttempt = DateTime.utc(2026, 8, 16, 10);
      final task = _task(1)
        ..status = status
        ..retryCount = 7
        ..lastError = 'önceki hata'
        ..lastAttemptAt = previousAttempt;
      final repository = _MemoryGroupSyncRepository([])..addRetryable(task);
      final scope = container(
        repository: repository,
        server: FakeGroupSyncServer(),
      );

      await scope.read(groupSyncCoordinatorProvider.notifier).manualRetry();

      expect(repository.requeueCalls, 1);
      expect(task.status, OfflineTaskStatus.synced);
      expect(task.retryCount, 7);
      expect(task.lastError, 'önceki hata');
      expect(task.lastAttemptAt, DateTime.utc(2026, 8, 17, 12));
      expect(
        scope.read(groupSyncCoordinatorProvider).status,
        GroupSyncStatus.success,
      );
    });
  }

  test(
    'bağlantı geri gelince retryable failed grup görevini gönderir',
    () async {
      final task = _task(1)
        ..status = OfflineTaskStatus.failed
        ..retryCount = 5
        ..lastError = 'offline';
      final repository = _MemoryGroupSyncRepository([])..addRetryable(task);
      final scope = container(
        repository: repository,
        server: FakeGroupSyncServer(),
      );

      await scope
          .read(groupSyncCoordinatorProvider.notifier)
          .syncAfterConnectivityRestored();

      expect(repository.connectivityRequeueCalls, 1);
      expect(repository.requeueCalls, 0);
      expect(repository.syncedIds, <Id>[task.id]);
    },
  );

  test('pending task olmasa da fake pull değişikliklerini uygular', () async {
    final server = FakeGroupSyncServer()
      ..seedRemoteOperation(_operationJson(9));
    final repository = _MemoryGroupSyncRepository([]);
    final scope = container(repository: repository, server: server);

    await scope
        .read(groupSyncCoordinatorProvider.notifier)
        .syncPendingAndPull();

    final state = scope.read(groupSyncCoordinatorProvider);
    expect(repository.appliedChanges, hasLength(1));
    expect(state.pulledCount, 1);
    expect(state.status, GroupSyncStatus.success);
  });

  test(
    'pulledCount yalnız repository tarafından uygulanan kayıtları sayar',
    () async {
      final server = FakeGroupSyncServer()
        ..seedRemoteOperation(_operationJson(9));
      final repository = _MemoryGroupSyncRepository([], appliedChangeCount: 0);
      final scope = container(repository: repository, server: server);

      await scope
          .read(groupSyncCoordinatorProvider.notifier)
          .syncPendingAndPull();

      expect(repository.appliedChanges, hasLength(1));
      expect(scope.read(groupSyncCoordinatorProvider).pulledCount, 0);
    },
  );

  test('eş zamanlı sync çağrıları aynı push işlemini paylaşır', () async {
    final task = _task(1);
    final release = Completer<void>();
    final repository = _MemoryGroupSyncRepository([task]);
    final server = _BlockingFakeGroupSyncServer(release.future);
    final scope = container(repository: repository, server: server);
    final coordinator = scope.read(groupSyncCoordinatorProvider.notifier);

    final first = coordinator.syncPendingAndPull();
    final second = coordinator.syncPendingAndPull();
    await Future<void>.delayed(Duration.zero);
    release.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(server.pushCalls, 1);
    expect(repository.syncedIds, <Id>[task.id]);
  });
}

class _ThrowingGroupPushGateway implements GroupPushGateway {
  const _ThrowingGroupPushGateway(this.error);

  final Object error;

  @override
  Future<GroupPushResult> push(OfflineTask task) async => throw error;
}

class _BlockingFakeGroupSyncServer extends FakeGroupSyncServer {
  _BlockingFakeGroupSyncServer(this.release);

  final Future<void> release;
  int pushCalls = 0;

  @override
  Future<GroupPushResult> push(OfflineTask task) async {
    pushCalls += 1;
    await release;
    return super.push(task);
  }
}

class _MemoryGroupSyncRepository implements GroupSyncTaskRepository {
  _MemoryGroupSyncRepository(
    List<OfflineTask> pending, {
    this.appliedChangeCount,
  }) : _pending = <Id, OfflineTask>{for (final task in pending) task.id: task};

  final Map<Id, OfflineTask> _pending;
  final int? appliedChangeCount;
  final Map<Id, OfflineTask> _retryable = <Id, OfflineTask>{};
  final List<Id> syncedIds = <Id>[];
  final List<GroupPullChange> appliedChanges = <GroupPullChange>[];
  int requeueCalls = 0;
  int connectivityRequeueCalls = 0;

  void addRetryable(OfflineTask task) => _retryable[task.id] = task;

  @override
  Future<List<OfflineTask>> getPendingTasks({int limit = 50}) async =>
      _pending.values.take(limit).toList(growable: false);

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
    final task = _pending.remove(id)!;
    task
      ..status = OfflineTaskStatus.synced
      ..lastAttemptAt = DateTime.utc(2026, 8, 17, 12);
    syncedIds.add(id);
  }

  @override
  Future<void> recordRetryableError(Id id, String error) async {
    final task = _pending[id]!;
    task
      ..status = OfflineTaskStatus.pending
      ..retryCount += 1
      ..lastError = error
      ..lastAttemptAt = DateTime.utc(2026, 8, 17, 12);
  }

  @override
  Future<void> markPermanentlyFailed(Id id, String error) async {
    final task = _pending.remove(id)!;
    task
      ..status = OfflineTaskStatus.failed
      ..lastError = error
      ..lastAttemptAt = DateTime.utc(2026, 8, 17, 12);
  }

  @override
  Future<void> markConflict(Id id, String error) async {
    final task = _pending.remove(id)!;
    task
      ..status = OfflineTaskStatus.conflict
      ..lastError = error
      ..lastAttemptAt = DateTime.utc(2026, 8, 17, 12);
  }

  @override
  Future<int> applyPulledChanges(List<GroupPullChange> changes) async {
    appliedChanges.addAll(changes);
    return appliedChangeCount ?? changes.length;
  }
}

OfflineTask _task(int id) {
  final operation = _operationJson(id);
  return OfflineTask()
    ..id = id
    ..clientTaskId = operation['client_record_id']! as String
    ..type = OfflineTaskType.groupExpenseCreate
    ..status = OfflineTaskStatus.pending
    ..payloadJson = jsonEncode(operation)
    ..createdAt = DateTime.utc(2026, 8, 17)
    ..updatedAt = DateTime.utc(2026, 8, 17);
}

Map<String, Object?> _operationJson(int id) {
  final clientRecordId =
      '93000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  return <String, Object?>{
    'operation_type': OfflineTaskType.groupExpenseCreate.name,
    'group_id': '92000000-0000-4000-8000-000000000001',
    'client_record_id': clientRecordId,
    'owner_key': 'user:91000000-0000-4000-8000-000000000001',
    'sync_state': SyncState.pending.name,
    'payload': <String, Object?>{
      'id': '94000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
    },
  };
}
