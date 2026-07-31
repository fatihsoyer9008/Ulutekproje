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
}
