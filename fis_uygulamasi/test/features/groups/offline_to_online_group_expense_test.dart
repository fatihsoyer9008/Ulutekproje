import 'dart:io';

import 'package:app_main/features/groups/application/group_sync_coordinator.dart';
import 'package:app_main/features/groups/application/offline_first_group_expense_writer.dart';
import 'package:app_main/features/groups/data/group_sync_gateway.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/domain/group_offline_operation.dart';
import 'package:app_main/features/groups/domain/group_sync_state.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../fixtures/group_fixtures.dart';
import '../../fixtures/group_offline_operation_fixtures.dart';

void main() {
  setUpAll(() => Isar.initializeIsarCore(download: true));

  test(
    'offline create, online push, başka cihaz pull, duplicate, tombstone ve conflict zinciri',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'offline_to_online_group_expense_test_',
      );
      final deviceA = await Isar.open(
        [GroupExpenseEntitySchema, OfflineTaskSchema],
        directory: directory.path,
        name: 'offline_to_online_device_a',
      );
      final deviceB = await Isar.open(
        [GroupExpenseEntitySchema, OfflineTaskSchema],
        directory: directory.path,
        name: 'offline_to_online_device_b',
      );
      addTearDown(() async {
        await deviceA.close(deleteFromDisk: true);
        await deviceB.close(deleteFromDisk: true);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      var serverTime = DateTime.utc(2026, 8, 17, 12);
      final server = FakeGroupSyncServer(clock: () => serverTime);
      final repositoryA = GroupExpenseOfflineRepository(deviceA);
      final repositoryB = GroupExpenseOfflineRepository(deviceB);
      final writerA = OfflineFirstGroupExpenseWriter(repositoryA);
      final writerB = OfflineFirstGroupExpenseWriter(repositoryB);
      final scopeA = _deviceScope(repositoryA, server);
      final scopeB = _deviceScope(repositoryB, server);
      addTearDown(scopeA.dispose);
      addTearDown(scopeB.dispose);

      // 1. İnternet yokken masraf ve OfflineTask atomik olarak yerelde oluşur.
      await writerA.save(groupExpenseCreateOperation);

      final offlineExpense = await repositoryA.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      final offlineTasks = await deviceA.offlineTasks.where().findAll();
      expect(offlineExpense?.syncState, SyncState.pending);
      expect(offlineExpense?.deletedAt, isNull);
      expect(offlineTasks, hasLength(1));
      expect(offlineTasks.single.type, OfflineTaskType.groupExpenseCreate);
      expect(offlineTasks.single.status, OfflineTaskStatus.pending);
      expect(
        offlineTasks.single.clientTaskId,
        groupExpenseCreateOperation.clientRecordId,
      );

      // 2. İnternet gelince aynı task push edilir ve yerel kayıt synced olur.
      await scopeA
          .read(groupSyncCoordinatorProvider.notifier)
          .syncPendingAndPull();

      final pushedTask = (await deviceA.offlineTasks.where().findAll()).single;
      final pushedExpense = await repositoryA.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      expect(pushedTask.status, OfflineTaskStatus.synced);
      expect(pushedExpense?.syncState, SyncState.synced);
      expect(server.acceptedOperationCount, 1);
      expect(
        scopeA.read(groupSyncCoordinatorProvider).status,
        GroupSyncStatus.success,
      );

      // 3. Başka cihaz aynı değişikliği pull eder ve ayrı Isar'a uygular.
      await scopeB
          .read(groupSyncCoordinatorProvider.notifier)
          .syncPendingAndPull();

      final pulledOnDeviceB = await repositoryB.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      expect(await deviceB.groupExpenseEntitys.count(), 1);
      expect(pulledOnDeviceB?.title, fastSplitTransferExpense.title);
      expect(pulledOnDeviceB?.syncState, SyncState.synced);
      expect(scopeB.read(groupSyncCoordinatorProvider).pulledCount, 1);

      // 4. Aynı operation tekrar gönderilse de sunucuda/pull akışında duplicate
      // kayıt oluşmaz.
      final duplicate = await server.push(pushedTask);
      final afterDuplicate = await server.pull(cursor: '1');
      expect(duplicate.status, GroupPushStatus.duplicate);
      expect(server.acceptedOperationCount, 1);
      expect(afterDuplicate.changes, isEmpty);
      expect(await deviceA.groupExpenseEntitys.count(), 1);
      expect(await deviceB.groupExpenseEntitys.count(), 1);

      // 5. Silme önce cihaz A'da tombstone + pending delete task olur, push'tan
      // sonra cihaz B aynı tombstone'u pull eder; fiziksel duplicate oluşmaz.
      serverTime = DateTime.utc(2026, 8, 17, 13);
      await writerA.save(groupExpenseDeleteOperation);

      final pendingDelete = await repositoryA.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      final deleteTask = (await deviceA.offlineTasks.where().findAll())
          .singleWhere(
            (task) => task.type == OfflineTaskType.groupExpenseDelete,
          );
      expect(pendingDelete?.syncState, SyncState.pendingDelete);
      expect(pendingDelete?.deletedAt, isNotNull);
      expect(deleteTask.status, OfflineTaskStatus.pending);

      await scopeA
          .read(groupSyncCoordinatorProvider.notifier)
          .syncPendingAndPull();
      await scopeB
          .read(groupSyncCoordinatorProvider.notifier)
          .syncPendingAndPull();

      final deletedOnDeviceA = await repositoryA.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      final deletedOnDeviceB = await repositoryB.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      final syncedDeleteTask = (await deviceA.offlineTasks.where().findAll())
          .singleWhere(
            (task) => task.type == OfflineTaskType.groupExpenseDelete,
      );
      expect(syncedDeleteTask.status, OfflineTaskStatus.synced);
      expect(deletedOnDeviceA?.syncState, SyncState.synced);
      expect(deletedOnDeviceA?.deletedAt?.toUtc(), serverTime);
      expect(deletedOnDeviceB?.syncState, SyncState.synced);
      expect(deletedOnDeviceB?.deletedAt?.toUtc(), serverTime);
      expect(await deviceA.groupExpenseEntitys.count(), 1);
      expect(await deviceB.groupExpenseEntitys.count(), 1);
      expect(server.acceptedOperationCount, 2);

      // 6. Başka cihaz aynı operation ID'yi farklı payload ile kullanırsa task
      // retry edilmeden conflict olur ve sunucuda yeni kayıt oluşmaz.
      final changedJson = fastSplitTransferExpense.toJson()
        ..['title'] = 'Çakışan cihaz başlığı';
      final conflictingOperation = GroupExpenseOfflineOperation.create(
        expense: GroupExpense.fromJson(changedJson),
        clientRecordId: groupExpenseCreateOperation.clientRecordId,
        ownerKey: groupOperationOwnerKey,
      );
      await writerB.save(conflictingOperation);

      await scopeB
          .read(groupSyncCoordinatorProvider.notifier)
          .syncPendingAndPull();

      final conflictTask =
          (await deviceB.offlineTasks.where().findAll()).single;
      final conflictedExpense = await repositoryB.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      final conflictState = scopeB.read(groupSyncCoordinatorProvider);
      expect(conflictTask.status, OfflineTaskStatus.conflict);
      expect(conflictTask.retryCount, 0);
      expect(conflictTask.lastError, contains('farklı payload'));
      expect(conflictedExpense?.syncState, SyncState.failed);
      expect(conflictState.status, GroupSyncStatus.conflict);
      expect(conflictState.conflictCount, 1);
      expect(server.acceptedOperationCount, 2);
    },
  );
}

ProviderContainer _deviceScope(
  GroupExpenseOfflineRepository repository,
  FakeGroupSyncServer server,
) => ProviderContainer(
  overrides: [
    groupSyncTaskRepositoryProvider.overrideWithValue(
      IsarGroupSyncTaskRepository(repository, groupOperationOwnerKey),
    ),
    groupPushGatewayProvider.overrideWithValue(FakeGroupPushGateway(server)),
    groupPullGatewayProvider.overrideWithValue(FakeGroupPullGateway(server)),
    groupSyncCoordinatorProvider.overrideWith(
      () => GroupSyncCoordinator(
        initialBackoff: Duration.zero,
        delay: (_) async {},
      ),
    ),
  ],
);
