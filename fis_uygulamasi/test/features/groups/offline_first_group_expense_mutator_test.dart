import 'dart:convert';
import 'dart:io';

import 'package:app_main/features/groups/application/offline_first_group_expense_mutator.dart';
import 'package:app_main/features/groups/application/offline_first_group_expense_writer.dart';
import 'package:app_main/features/groups/data/group_offline_operation_mapper.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/domain/group_offline_operation.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../fixtures/group_fixtures.dart';
import '../../fixtures/group_offline_operation_fixtures.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late GroupExpenseOfflineRepository repository;
  late OfflineFirstGroupExpenseMutator mutator;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'offline_first_group_expense_mutator_test_',
    );
    isar = await Isar.open(
      [GroupExpenseEntitySchema, OfflineTaskSchema],
      directory: tempDirectory.path,
      name: 'offline_first_group_expense_mutator_test',
    );
    repository = GroupExpenseOfflineRepository(isar);
    mutator = OfflineFirstGroupExpenseMutator(
      repository,
      OfflineFirstGroupExpenseWriter(repository),
      clock: () => DateTime.utc(2026, 8, 18, 12),
    );
  });

  setUp(() => isar.writeTxn(isar.clear));

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'metadata update snapshot ve expected version ile kuyruğa yazılır',
    () async {
      await _seedSynced(repository, fastSplitTransferExpense);

      final updated = await mutator.updateMetadata(
        expense: fastSplitTransferExpense,
        ownerKey: groupOperationOwnerKey,
        clientRecordId: '65000000-0000-4000-8000-000000000001',
        title: '  Güncel market  ',
        note: '  Haftalık alışveriş  ',
      );

      final entity = await repository.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      final task = (await isar.offlineTasks.where().findAll()).single;
      final envelope = jsonDecode(task.payloadJson) as Map<String, dynamic>;
      final syncPayload = envelope['sync_payload'] as Map<String, dynamic>;
      expect(updated.title, 'Güncel market');
      expect(updated.note, 'Haftalık alışveriş');
      expect(entity?.syncState, SyncState.pending);
      expect(task.type, OfflineTaskType.groupExpenseUpdate);
      expect(
        syncPayload['expected_updated_at'],
        fastSplitTransferExpense.updatedAt,
      );
      expect(syncPayload['title'], 'Güncel market');
    },
  );

  test('delete tombstone ve expected version ile kuyruğa yazılır', () async {
    await _seedSynced(repository, fastSplitTransferExpense);

    await mutator.delete(
      expense: fastSplitTransferExpense,
      ownerKey: groupOperationOwnerKey,
      clientRecordId: '65000000-0000-4000-8000-000000000002',
    );

    final entity = await repository.getByExpenseId(fastSplitTransferExpense.id);
    final task = (await isar.offlineTasks.where().findAll()).single;
    final envelope = jsonDecode(task.payloadJson) as Map<String, dynamic>;
    final syncPayload = envelope['sync_payload'] as Map<String, dynamic>;
    expect(entity?.syncState, SyncState.pendingDelete);
    expect(entity?.deletedAt, isNotNull);
    expect(task.type, OfflineTaskType.groupExpenseDelete);
    expect(
      syncPayload['expected_updated_at'],
      fastSplitTransferExpense.updatedAt,
    );
    expect(syncPayload['expense_id'], fastSplitTransferExpense.id);
  });

  test('ilk create senkronize olmadan update ve delete başlatılmaz', () async {
    await OfflineFirstGroupExpenseWriter(
      repository,
    ).save(groupExpenseCreateOperation);

    await expectLater(
      mutator.updateMetadata(
        expense: fastSplitTransferExpense,
        ownerKey: groupOperationOwnerKey,
        clientRecordId: '65000000-0000-4000-8000-000000000003',
        title: 'Erken update',
        note: null,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      mutator.delete(
        expense: fastSplitTransferExpense,
        ownerKey: groupOperationOwnerKey,
        clientRecordId: '65000000-0000-4000-8000-000000000004',
      ),
      throwsA(isA<StateError>()),
    );
    expect(await isar.offlineTasks.count(), 1);
  });

  test('finansal olarak kilitli masraf delete kuyruğuna alınmaz', () async {
    final locked = GroupExpense.fromJson(<String, Object?>{
      ...fastSplitTransferExpense.toJson(),
      'is_financially_locked': true,
    });
    await _seedSynced(repository, locked);

    await expectLater(
      mutator.delete(
        expense: locked,
        ownerKey: groupOperationOwnerKey,
        clientRecordId: '65000000-0000-4000-8000-000000000005',
      ),
      throwsA(isA<StateError>()),
    );
    expect(await isar.offlineTasks.count(), 0);
  });
}

Future<void> _seedSynced(
  GroupExpenseOfflineRepository repository,
  GroupExpense expense,
) async {
  await repository.saveSyncedFromPull(
    GroupExpenseOfflineOperation.create(
      expense: expense,
      clientRecordId: '64000000-0000-4000-8000-000000000001',
      ownerKey: groupOperationOwnerKey,
      syncState: SyncState.synced,
    ).toGroupExpenseEntity(),
  );
}
