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

OfflineTask _task({String ownerKey = 'user:test-user'}) => OfflineTask()
  ..clientTaskId = _clientRecordId
  ..type = OfflineTaskType.groupExpenseCreate
  ..payloadJson = jsonEncode(<String, Object?>{
    'operation_type': OfflineTaskType.groupExpenseCreate.name,
    'group_id': _groupId,
    'client_record_id': _clientRecordId,
    'owner_key': ownerKey,
    'sync_state': SyncState.pending.name,
    'payload': const <String, Object?>{'id': _expenseId},
  });
