import 'dart:convert';
import 'dart:io';

import 'package:app_main/features/groups/application/offline_first_group_expense_writer.dart';
import 'package:app_main/features/groups/data/group_offline_operation_mapper.dart';
import 'package:app_main/features/groups/domain/group_offline_operation.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../fixtures/group_fixtures.dart';
import '../../fixtures/group_offline_operation_fixtures.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late OfflineFirstGroupExpenseWriter writer;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'group_offline_persistence_test_',
    );
    isar = await Isar.open(
      [GroupExpenseEntitySchema, OfflineTaskSchema],
      directory: tempDirectory.path,
      name: 'group_offline_persistence_test',
    );
    writer = OfflineFirstGroupExpenseWriter(
      GroupExpenseOfflineRepository(isar),
    );
  });

  setUp(() => isar.writeTxn(isar.clear));

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('tüm grup operasyon türleri OfflineTask ile birebir eşleşir', () {
    for (final operation in allGroupOfflineOperationFixtures) {
      final task = operation.toOfflineTask();

      expect(task.type.name, operation.type.name);
      expect(task.clientTaskId, operation.clientRecordId);
      expect(jsonDecode(task.payloadJson), operation.toJson());
    }
  });

  test(
    'oturum açmış kullanıcının masrafı ve görevi birlikte yazılır',
    () async {
      await writer.save(groupExpenseCreateOperation);

      final expenses = await isar.groupExpenseEntitys.where().findAll();
      final tasks = await isar.offlineTasks.where().findAll();
      expect(expenses, hasLength(1));
      expect(tasks, hasLength(1));
      expect(expenses.single.expenseId, fastSplitTransferExpense.id);
      expect(tasks.single.type, OfflineTaskType.groupExpenseCreate);
    },
  );

  test('guest masrafı yerelde kalır ve sync kuyruğuna girmez', () async {
    final guestOperation = GroupExpenseOfflineOperation.create(
      expense: fastSplitTransferExpense,
      clientRecordId: '85000000-0000-4000-8000-000000000001',
      ownerKey: 'guest:installation-test',
    );

    await writer.save(guestOperation);

    final expenses = await isar.groupExpenseEntitys.where().findAll();
    expect(expenses, hasLength(1));
    expect(expenses.single.ownerKey, 'guest:installation-test');
    expect(expenses.single.syncState, SyncState.localOnly);
    expect(await isar.offlineTasks.count(), 0);
  });
}
