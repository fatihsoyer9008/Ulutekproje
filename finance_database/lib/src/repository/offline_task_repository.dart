import 'package:isar/isar.dart';

import '../models/offline_task.dart';

class OfflineTaskRepository {
  OfflineTaskRepository(this._isar);

  final Isar _isar;

  Future<Id> add(OfflineTask task) async {
    final now = DateTime.now();
    task.createdAt = now;
    task.updatedAt = now;

    return _isar.writeTxn(() => _isar.offlineTasks.put(task));
  }

  Future<OfflineTask?> getById(Id id) => _isar.offlineTasks.get(id);

  Future<List<OfflineTask>> getAll() =>
      _isar.offlineTasks.where().sortByCreatedAt().findAll();

  Future<List<OfflineTask>> getPending({int limit = 50}) {
    if (limit <= 0) return Future.value(const []);

    return _isar.offlineTasks
        .filter()
        .statusEqualTo(OfflineTaskStatus.pending)
        .sortByCreatedAt()
        .limit(limit)
        .findAll();
  }

  Stream<List<OfflineTask>> watchPending() => _isar.offlineTasks
      .filter()
      .statusEqualTo(OfflineTaskStatus.pending)
      .sortByCreatedAt()
      .watch(fireImmediately: true);

  Future<void> update(OfflineTask task) async {
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.offlineTasks.put(task));
  }

  Future<void> markFailed(Id id, String error) async {
    await _isar.writeTxn(() async {
      final task = await _isar.offlineTasks.get(id);
      if (task == null) return;

      task
        ..status = OfflineTaskStatus.failed
        ..retryCount += 1
        ..lastError = error
        ..lastAttemptAt = DateTime.now()
        ..updatedAt = DateTime.now();
      await _isar.offlineTasks.put(task);
    });
  }

  Future<bool> delete(Id id) =>
      _isar.writeTxn(() => _isar.offlineTasks.delete(id));
}
