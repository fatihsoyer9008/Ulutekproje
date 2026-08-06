import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late OfflineTaskRepository repository;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'offline_task_repository_test_',
    );
    isar = await Isar.open(
      [OfflineTaskSchema],
      directory: tempDirectory.path,
      name: 'offline_task_repository_test',
    );
    repository = OfflineTaskRepository(isar);
  });

  setUp(() => isar.writeTxn(isar.clear));

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  OfflineTask task(String clientTaskId) => OfflineTask()
    ..clientTaskId = clientTaskId
    ..type = OfflineTaskType.createTransaction
    ..payloadJson = '{"amountInMinor":2550}';

  test('çevrimdışı görevi ekler ve ID ile getirir', () async {
    final id = await repository.add(task('task-create'));

    final stored = await repository.getById(id);

    expect(stored, isNotNull);
    expect(stored!.clientTaskId, 'task-create');
    expect(stored.status, OfflineTaskStatus.pending);
    expect(stored.createdAt, isNotNull);
  });

  test('yalnızca bekleyen görevleri oluşturulma sırasıyla getirir', () async {
    final first = task('task-first')..createdAt = DateTime(2026, 7, 30, 10);
    final second = task('task-second')..createdAt = DateTime(2026, 7, 30, 11);

    await repository.add(first);
    final secondId = await repository.add(second);
    await repository.markFailed(secondId, 'Bağlantı kurulamadı');

    final pending = await repository.getPending();

    expect(pending, hasLength(1));
    expect(pending.single.clientTaskId, 'task-first');
  });

  test('görevi günceller ve siler', () async {
    final id = await repository.add(task('task-update'));
    final stored = (await repository.getById(id))!
      ..status = OfflineTaskStatus.processing;

    await repository.update(stored);
    expect(
      (await repository.getById(id))!.status,
      OfflineTaskStatus.processing,
    );

    expect(await repository.delete(id), isTrue);
    expect(await repository.getById(id), isNull);
  });

  test('conflict görevini pending kuyruğundan çıkarır', () async {
    final id = await repository.add(task('task-conflict'));

    await repository.markConflict(id, 'server has a newer value');

    final stored = (await repository.getById(id))!;
    expect(stored.status, OfflineTaskStatus.conflict);
    expect(stored.lastError, 'server has a newer value');
    expect(await repository.getPendingTasks(), isEmpty);
  });

  test(
    'queue summary pending failed ve conflict durumlarını kalıcı okur',
    () async {
      final pendingId = await repository.add(task('task-pending-summary'));
      final failedId = await repository.add(task('task-failed-summary'));
      final conflictId = await repository.add(task('task-conflict-summary'));
      await repository.markFailed(failedId, 'offline');
      await repository.markConflict(conflictId, 'newer server value');

      final summary = await repository.getQueueSummary();

      expect(pendingId, isPositive);
      expect(summary.pendingCount, 1);
      expect(summary.failedCount, 1);
      expect(summary.conflictCount, 1);
      expect(summary.retryableCount, 2);
    },
  );

  test(
    'failed ve conflict görevleri audit bilgisi korunarak pending yapılır',
    () async {
      final failedId = await repository.add(task('task-failed-retry'));
      final conflictId = await repository.add(task('task-conflict-retry'));
      await repository.markFailed(failedId, 'offline');
      await repository.markConflict(conflictId, 'newer server value');
      final failedBefore = (await repository.getById(failedId))!;
      final conflictBefore = (await repository.getById(conflictId))!;

      final requeued = await repository.requeueFailedAndConflicted();

      expect(requeued, {failedId, conflictId});
      final failedAfter = (await repository.getById(failedId))!;
      final conflictAfter = (await repository.getById(conflictId))!;
      expect(failedAfter.status, OfflineTaskStatus.pending);
      expect(failedAfter.retryCount, failedBefore.retryCount);
      expect(failedAfter.lastError, failedBefore.lastError);
      expect(conflictAfter.status, OfflineTaskStatus.pending);
      expect(conflictAfter.retryCount, conflictBefore.retryCount);
      expect(conflictAfter.lastError, conflictBefore.lastError);
    },
  );

  test('yalnızca cutoff öncesindeki synced görevleri temizler', () async {
    final oldId = await repository.add(task('task-old'));
    final recentId = await repository.add(task('task-recent'));
    await repository.markAsSynced(oldId);
    await repository.markAsSynced(recentId);
    await isar.writeTxn(() async {
      final old = (await isar.offlineTasks.get(oldId))!
        ..updatedAt = DateTime.utc(2026, 7, 1);
      final recent = (await isar.offlineTasks.get(recentId))!
        ..updatedAt = DateTime.utc(2026, 8, 1);
      await isar.offlineTasks.putAll([old, recent]);
    });

    final deleted = await repository.deleteSyncedBefore(
      DateTime.utc(2026, 7, 29),
    );

    expect(deleted, 1);
    expect(await repository.getById(oldId), isNull);
    expect(await repository.getById(recentId), isNotNull);
  });
}
