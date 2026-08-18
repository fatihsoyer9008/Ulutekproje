import 'dart:convert';
import 'dart:io';

import 'package:app_main/features/groups/application/group_expense_conflict_service.dart';
import 'package:app_main/features/groups/application/offline_first_group_expense_writer.dart';
import 'package:app_main/features/groups/data/group_repository.dart';
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

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'group_expense_conflict_service_test_',
    );
    isar = await Isar.open(
      [GroupExpenseEntitySchema, OfflineTaskSchema],
      directory: tempDirectory.path,
      name: 'group_expense_conflict_service_test',
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

  test('conflict hata kodu ve yerel snapshot UI modeline taşınır', () async {
    await _seedConflict(
      repository,
      message: jsonEncode(<String, Object?>{
        'kind': 'group_sync_conflict',
        'code': 'version_mismatch',
        'message': 'Başka cihazda güncellendi.',
      }),
    );
    final service = GroupExpenseConflictService(
      repository,
      _RemoteExpenseRepository([fastSplitTransferExpense]),
      () => '66000000-0000-4000-8000-000000000001',
    );

    final conflicts = await service
        .watch(ownerKey: groupOperationOwnerKey)
        .first;

    expect(conflicts, hasLength(1));
    expect(conflicts.single.code, 'version_mismatch');
    expect(conflicts.single.message, 'Başka cihazda güncellendi.');
    expect(conflicts.single.localExpense?.title, 'Yerel değişiklik');
    expect(conflicts.single.canKeepLocal, isTrue);
  });

  test(
    'sunucu sürümü seçilince conflict kapanır ve cache güncellenir',
    () async {
      await _seedConflict(repository);
      final remote = GroupExpense.fromJson(<String, Object?>{
        ...fastSplitTransferExpense.toJson(),
        'title': 'Sunucu değişikliği',
        'updated_at': '2026-08-18T14:00:00Z',
      });
      var syncCalls = 0;
      final service = GroupExpenseConflictService(
        repository,
        _RemoteExpenseRepository([remote]),
        () => '66000000-0000-4000-8000-000000000002',
        () async => syncCalls += 1,
      );
      final conflict =
          (await service.watch(ownerKey: groupOperationOwnerKey).first).single;

      await service.useServerVersion(
        conflict,
        ownerKey: groupOperationOwnerKey,
      );

      final task = (await isar.offlineTasks.where().findAll()).single;
      final expense = await repository.getByExpenseId(
        fastSplitTransferExpense.id,
      );
      expect(task.status, OfflineTaskStatus.synced);
      expect(expense?.title, 'Sunucu değişikliği');
      expect(expense?.syncState, SyncState.synced);
      expect(syncCalls, 1);
    },
  );

  test(
    'yerel sürüm yeni id ve güncel expected version ile tekrar kuyruğa girer',
    () async {
      await _seedConflict(repository);
      final remote = GroupExpense.fromJson(<String, Object?>{
        ...fastSplitTransferExpense.toJson(),
        'title': 'Sunucu değişikliği',
        'updated_at': '2026-08-18T15:00:00Z',
      });
      const replacementId = '66000000-0000-4000-8000-000000000003';
      final service = GroupExpenseConflictService(
        repository,
        _RemoteExpenseRepository([remote]),
        () => replacementId,
      );
      final conflict =
          (await service.watch(ownerKey: groupOperationOwnerKey).first).single;

      await service.keepLocalVersion(
        conflict,
        ownerKey: groupOperationOwnerKey,
      );

      final tasks = await isar.offlineTasks.where().sortByCreatedAt().findAll();
      expect(tasks, hasLength(2));
      expect(tasks.first.status, OfflineTaskStatus.synced);
      expect(tasks.last.status, OfflineTaskStatus.pending);
      expect(tasks.last.clientTaskId, replacementId);
      final envelope =
          jsonDecode(tasks.last.payloadJson) as Map<String, dynamic>;
      final syncPayload = envelope['sync_payload'] as Map<String, dynamic>;
      expect(syncPayload['expected_updated_at'], remote.updatedAt);
      expect(syncPayload['title'], 'Yerel değişiklik');
      expect(
        (await repository.getByExpenseId(
          fastSplitTransferExpense.id,
        ))?.syncState,
        SyncState.pending,
      );
    },
  );

  test('finansal kilit conflictında yerel overwrite engellenir', () async {
    await _seedConflict(
      repository,
      message: jsonEncode(<String, Object?>{
        'kind': 'group_sync_conflict',
        'code': 'expense_financially_locked',
        'message': 'Masraf kilitli.',
      }),
    );
    final service = GroupExpenseConflictService(
      repository,
      _RemoteExpenseRepository([fastSplitTransferExpense]),
      () => '66000000-0000-4000-8000-000000000004',
    );
    final conflict =
        (await service.watch(ownerKey: groupOperationOwnerKey).first).single;

    expect(conflict.canKeepLocal, isFalse);
    await expectLater(
      service.keepLocalVersion(conflict, ownerKey: groupOperationOwnerKey),
      throwsA(isA<StateError>()),
    );
    expect(
      (await isar.offlineTasks.where().findAll()).single.status,
      OfflineTaskStatus.conflict,
    );
  });
}

Future<void> _seedConflict(
  GroupExpenseOfflineRepository repository, {
  String message = 'version conflict',
}) async {
  final local = GroupExpense.fromJson(<String, Object?>{
    ...fastSplitTransferExpense.toJson(),
    'title': 'Yerel değişiklik',
    'updated_at': '2026-08-18T13:00:00Z',
  });
  final operation = GroupExpenseOfflineOperation.update(
    expense: local,
    clientRecordId: '65000000-0000-4000-8000-000000000020',
    ownerKey: groupOperationOwnerKey,
    expectedUpdatedAt: fastSplitTransferExpense.updatedAt,
  );
  await OfflineFirstGroupExpenseWriter(repository).save(operation);
  final task = (await repository.getPendingSyncTasks(
    ownerKey: groupOperationOwnerKey,
  )).single;
  await repository.markSyncTaskConflict(task.id, message);
}

class _RemoteExpenseRepository implements GroupExpenseRepository {
  const _RemoteExpenseRepository(this.expenses);

  final List<GroupExpense> expenses;

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) async => expenses;

  @override
  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  }) async => expenses.firstWhere((expense) => expense.id == expenseId);

  @override
  Future<GroupExpense> createExpense(
    CreateGroupExpenseRequest request, {
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupExpense> createFastSplit(
    FastSplitExpenseRequest request, {
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupExpense> createItemizedSplit(
    ItemizedExpenseRequest request, {
    required String idempotencyKey,
  }) => throw UnimplementedError();
}
