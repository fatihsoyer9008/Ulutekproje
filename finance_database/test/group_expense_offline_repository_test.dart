import 'dart:convert';
import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late GroupExpenseOfflineRepository repository;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'group_expense_offline_repository_test_',
    );
    isar = await Isar.open(
      [GroupExpenseEntitySchema, OfflineTaskSchema],
      directory: tempDirectory.path,
      name: 'group_expense_offline_repository_test',
    );
    repository = GroupExpenseOfflineRepository(isar);
  });

  setUp(() => isar.writeTxn(isar.clear));

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('pending grup masrafı ve OfflineTask atomik kaydedilir', () async {
    final expense = _expense();
    final task = _task();

    final id = await repository.savePendingWithOfflineTask(expense, task);

    expect(id, isPositive);
    expect(await isar.groupExpenseEntitys.count(), 1);
    expect(await isar.offlineTasks.count(), 1);
    expect(
      (await repository.getByExpenseId(expense.expenseId))?.syncState,
      SyncState.pending,
    );
  });

  test('pending masraf OfflineTask olmadan kaydedilemez', () {
    expect(
      () => repository.saveLocalOnly(_expense()),
      throwsA(isA<StateError>()),
    );
    expect(isar.groupExpenseEntitys.count(), completion(0));
  });

  test('OfflineTask yazımı başarısız olursa masraf rollback edilir', () async {
    final duplicateTask = _task();
    final now = DateTime.utc(2026, 8, 17);
    duplicateTask
      ..createdAt = now
      ..updatedAt = now;
    await isar.writeTxn(() => isar.offlineTasks.put(duplicateTask));

    await expectLater(
      repository.savePendingWithOfflineTask(_expense(), _task()),
      throwsA(anything),
    );

    expect(await isar.groupExpenseEntitys.count(), 0);
    expect(await isar.offlineTasks.count(), 1);
  });

  test('guest sahibi grup sync kuyruğuna eklenmez', () {
    final expense = _expense(ownerKey: 'guest:installation-test');
    final task = _task(ownerKey: 'guest:installation-test');

    expect(
      () => repository.savePendingWithOfflineTask(expense, task),
      throwsA(isA<StateError>()),
    );
    expect(isar.groupExpenseEntitys.count(), completion(0));
    expect(isar.offlineTasks.count(), completion(0));
  });

  test('pending sync sorgusu yalnız grup tasklarını döndürür', () async {
    final groupTask = _task();
    final personalTask = _task()
      ..clientTaskId = '83000000-0000-4000-8000-000000000099'
      ..type = OfflineTaskType.createTransaction;
    final now = DateTime.utc(2026, 8, 17);
    for (final task in <OfflineTask>[groupTask, personalTask]) {
      task
        ..createdAt = now
        ..updatedAt = now;
    }
    await isar.writeTxn(
      () => isar.offlineTasks.putAll([groupTask, personalTask]),
    );

    final result = await repository.getPendingSyncTasks(
      ownerKey: 'user:test-user',
    );

    expect(result.map((task) => task.id), <int>[groupTask.id]);
  });

  test('pending grup görevleri ownerKey değişiminde izole edilir', () async {
    final userA = _task(
      ownerKey: 'user:a',
      clientRecordId: '83000000-0000-4000-8000-000000000011',
    );
    final userB = _task(
      ownerKey: 'user:b',
      clientRecordId: '83000000-0000-4000-8000-000000000012',
    );
    final now = DateTime.utc(2026, 8, 17);
    for (final task in <OfflineTask>[userA, userB]) {
      task
        ..createdAt = now
        ..updatedAt = now;
    }
    await isar.writeTxn(
      () => isar.offlineTasks.putAll(<OfflineTask>[userA, userB]),
    );

    final visibleToB = await repository.getPendingSyncTasks(ownerKey: 'user:b');

    expect(visibleToB.map((task) => task.clientTaskId), <String>[
      userB.clientTaskId,
    ]);
  });

  test('geçici hata retry audit alanlarını ve pending masrafı korur', () async {
    final expense = _expense();
    final task = _task();
    await repository.savePendingWithOfflineTask(expense, task);

    await repository.recordSyncTaskError(task.id, 'network unavailable');

    final storedTask = (await isar.offlineTasks.get(task.id))!;
    final storedExpense = (await repository.getByExpenseId(expense.expenseId))!;
    expect(storedTask.status, OfflineTaskStatus.pending);
    expect(storedTask.retryCount, 1);
    expect(storedTask.lastError, 'network unavailable');
    expect(storedTask.lastAttemptAt, isNotNull);
    expect(storedExpense.syncState, SyncState.pending);
  });

  test(
    'başarı task ve masrafı atomik synced yapıp audit alanlarını korur',
    () async {
      final expense = _expense();
      final task = _task()
        ..retryCount = 2
        ..lastError = 'previous timeout'
        ..lastAttemptAt = DateTime.utc(2026, 8, 16);
      await repository.savePendingWithOfflineTask(expense, task);

      await repository.markSyncTaskAsSynced(task.id);

      final storedTask = (await isar.offlineTasks.get(task.id))!;
      final storedExpense = (await repository.getByExpenseId(
        expense.expenseId,
      ))!;
      expect(storedTask.status, OfflineTaskStatus.synced);
      expect(storedTask.retryCount, 2);
      expect(storedTask.lastError, 'previous timeout');
      expect(storedTask.lastAttemptAt, isNotNull);
      expect(storedExpense.syncState, SyncState.synced);
    },
  );

  for (final status in <OfflineTaskStatus>[
    OfflineTaskStatus.failed,
    OfflineTaskStatus.conflict,
  ]) {
    test('$status geçişi task auditini ve masraf durumunu günceller', () async {
      final expense = _expense();
      final task = _task();
      await repository.savePendingWithOfflineTask(expense, task);

      if (status == OfflineTaskStatus.failed) {
        await repository.markSyncTaskFailed(task.id, 'permanent failure');
      } else {
        await repository.markSyncTaskConflict(task.id, 'server conflict');
      }

      final storedTask = (await isar.offlineTasks.get(task.id))!;
      final storedExpense = (await repository.getByExpenseId(
        expense.expenseId,
      ))!;
      expect(storedTask.status, status);
      expect(storedTask.lastError, isNotEmpty);
      expect(storedTask.lastAttemptAt, isNotNull);
      expect(storedExpense.syncState, SyncState.failed);
    });
  }

  for (final status in <OfflineTaskStatus>[
    OfflineTaskStatus.failed,
    OfflineTaskStatus.conflict,
  ]) {
    test('$status manuel retry audit alanlarını değiştirmez', () async {
      final expense = _expense()..syncState = SyncState.failed;
      final task = _task()
        ..status = status
        ..retryCount = 4
        ..lastError = 'audit error'
        ..lastAttemptAt = DateTime.utc(2026, 8, 16);
      final now = DateTime.utc(2026, 8, 17);
      task
        ..createdAt = now
        ..updatedAt = now;
      await isar.writeTxn(() async {
        await isar.groupExpenseEntitys.put(expense);
        await isar.offlineTasks.put(task);
      });

      final ids = await repository.requeueFailedAndConflictedSyncTasks();

      final storedTask = (await isar.offlineTasks.get(task.id))!;
      final storedExpense = (await repository.getByExpenseId(
        expense.expenseId,
      ))!;
      expect(ids, <Id>{task.id});
      expect(storedTask.status, OfflineTaskStatus.pending);
      expect(storedTask.retryCount, 4);
      expect(storedTask.lastError, 'audit error');
      expect(storedTask.lastAttemptAt?.toUtc(), DateTime.utc(2026, 8, 16));
      expect(storedExpense.syncState, SyncState.pending);
    });
  }

  test('pull snapshotı pending yerel masrafı ezmez', () async {
    final pending = _expense();
    await repository.savePendingWithOfflineTask(pending, _task());
    final remote = _expense()
      ..title = 'Remote title'
      ..syncState = SyncState.synced;

    final applied = await repository.saveSyncedFromPull(remote);

    expect(applied, isFalse);
    expect(
      (await repository.getByExpenseId(pending.expenseId))?.title,
      'Market',
    );
  });

  test('delete tombstone ve OfflineTask atomik kaydedilir', () async {
    final expense = _expense()..syncState = SyncState.synced;
    await repository.saveSyncedFromPull(expense);
    final task = _deleteTask();
    final deletedAt = DateTime.utc(2026, 8, 17, 13);

    await repository.markPendingDeleteWithOfflineTask(
      expenseId: _expenseId,
      groupId: _groupId,
      ownerKey: 'user:test-user',
      task: task,
      deletedAt: deletedAt,
    );

    final stored = (await repository.getByExpenseId(_expenseId))!;
    expect(stored.syncState, SyncState.pendingDelete);
    expect(stored.deletedAt?.toUtc(), deletedAt);
    expect((jsonDecode(stored.payloadJson) as Map)['deleted_at'], isNotNull);
    expect(
      (await isar.offlineTasks.get(task.id))?.status,
      OfflineTaskStatus.pending,
    );
  });

  test(
    'delete task yazımı başarısız olursa tombstone rollback edilir',
    () async {
      final expense = _expense()..syncState = SyncState.synced;
      await repository.saveSyncedFromPull(expense);
      final existingTask = _deleteTask();
      final createdAt = DateTime.utc(2026, 8, 17, 12);
      existingTask
        ..createdAt = createdAt
        ..updatedAt = createdAt;
      await isar.writeTxn(() => isar.offlineTasks.put(existingTask));

      await expectLater(
        repository.markPendingDeleteWithOfflineTask(
          expenseId: _expenseId,
          groupId: _groupId,
          ownerKey: 'user:test-user',
          task: _deleteTask(),
        ),
        throwsA(anything),
      );

      final stored = (await repository.getByExpenseId(_expenseId))!;
      expect(stored.syncState, SyncState.synced);
      expect(stored.deletedAt, isNull);
      expect(await isar.offlineTasks.count(), 1);
    },
  );

  test('pull tombstone synced kayda uygulanır, pending kaydı ezmez', () async {
    final expense = _expense()..syncState = SyncState.synced;
    await repository.saveSyncedFromPull(expense);
    final deletedAt = DateTime.utc(2026, 8, 17, 14);

    expect(
      await repository.applyPulledTombstone(
        expenseId: _expenseId,
        groupId: _groupId,
        ownerKey: 'user:test-user',
        deletedAt: deletedAt,
      ),
      isTrue,
    );
    final tombstone = (await repository.getByExpenseId(_expenseId))!;
    expect(tombstone.syncState, SyncState.synced);
    expect(tombstone.deletedAt?.toUtc(), deletedAt);

    tombstone.syncState = SyncState.pending;
    await isar.writeTxn(() => isar.groupExpenseEntitys.put(tombstone));
    expect(
      await repository.applyPulledTombstone(
        expenseId: _expenseId,
        groupId: _groupId,
        ownerKey: 'user:test-user',
        deletedAt: deletedAt.add(const Duration(hours: 1)),
      ),
      isFalse,
    );
    expect(
      (await repository.getByExpenseId(_expenseId))?.deletedAt?.toUtc(),
      deletedAt,
    );
  });
}

const _expenseId = '81000000-0000-4000-8000-000000000001';
const _groupId = '82000000-0000-4000-8000-000000000001';
const _clientRecordId = '83000000-0000-4000-8000-000000000001';

GroupExpenseEntity _expense({String ownerKey = 'user:test-user'}) =>
    GroupExpenseEntity()
      ..expenseId = _expenseId
      ..groupId = _groupId
      ..clientRecordId = _clientRecordId
      ..ownerKey = ownerKey
      ..payerUserId = '84000000-0000-4000-8000-000000000001'
      ..title = 'Market'
      ..expenseDate = DateTime.utc(2026, 8, 17)
      ..totalAmountInMinor = 4250
      ..currency = 'TRY'
      ..splitType = 'equal'
      ..syncState = SyncState.pending
      ..payloadJson = '{"id":"$_expenseId"}'
      ..createdAt = DateTime.utc(2026, 8, 17)
      ..updatedAt = DateTime.utc(2026, 8, 17);

OfflineTask _task({
  String ownerKey = 'user:test-user',
  String clientRecordId = _clientRecordId,
}) => OfflineTask()
  ..clientTaskId = clientRecordId
  ..type = OfflineTaskType.groupExpenseCreate
  ..payloadJson = jsonEncode(<String, Object?>{
    'operation_type': OfflineTaskType.groupExpenseCreate.name,
    'group_id': _groupId,
    'client_record_id': clientRecordId,
    'owner_key': ownerKey,
    'sync_state': SyncState.pending.name,
    'payload': const <String, Object?>{'id': _expenseId},
  });

OfflineTask _deleteTask() => OfflineTask()
  ..clientTaskId = '83000000-0000-4000-8000-000000000002'
  ..type = OfflineTaskType.groupExpenseDelete
  ..payloadJson = jsonEncode(<String, Object?>{
    'operation_type': OfflineTaskType.groupExpenseDelete.name,
    'group_id': _groupId,
    'client_record_id': '83000000-0000-4000-8000-000000000002',
    'owner_key': 'user:test-user',
    'sync_state': SyncState.pendingDelete.name,
    'payload': const <String, Object?>{
      'group_id': _groupId,
      'expense_id': _expenseId,
    },
  });
