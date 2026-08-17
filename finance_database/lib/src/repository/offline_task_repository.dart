import 'package:isar/isar.dart';

import '../models/offline_task.dart';

class OfflineQueueSummary {
  const OfflineQueueSummary({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.conflictCount = 0,
  });

  final int pendingCount;
  final int failedCount;
  final int conflictCount;

  int get retryableCount => failedCount + conflictCount;
  bool get hasPending => pendingCount > 0;
  bool get hasFailures => failedCount > 0;
  bool get hasConflicts => conflictCount > 0;
}

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

  /// Sync katmanının kullandığı açık isimli API.
  Future<List<OfflineTask>> getPendingTasks({int limit = 50}) =>
      getPending(limit: limit);

  /// Kişisel transaction coordinator'ının grup görevlerini yanlış endpoint'e
  /// göndermesini engeller.
  Future<List<OfflineTask>> getPendingPersonalTasks({int limit = 50}) async {
    if (limit <= 0) return const [];
    final tasks = await _isar.offlineTasks
        .filter()
        .statusEqualTo(OfflineTaskStatus.pending)
        .sortByCreatedAt()
        .findAll();
    return tasks
        .where((task) => !task.type.isGroupOperation)
        .take(limit)
        .toList(growable: false);
  }

  Stream<List<OfflineTask>> watchPending() => _isar.offlineTasks
      .filter()
      .statusEqualTo(OfflineTaskStatus.pending)
      .sortByCreatedAt()
      .watch(fireImmediately: true);

  Future<OfflineQueueSummary> getQueueSummary() async {
    final counts = await Future.wait([
      _isar.offlineTasks
          .filter()
          .statusEqualTo(OfflineTaskStatus.pending)
          .count(),
      _isar.offlineTasks
          .filter()
          .statusEqualTo(OfflineTaskStatus.failed)
          .count(),
      _isar.offlineTasks
          .filter()
          .statusEqualTo(OfflineTaskStatus.conflict)
          .count(),
    ]);
    return OfflineQueueSummary(
      pendingCount: counts[0],
      failedCount: counts[1],
      conflictCount: counts[2],
    );
  }

  Stream<OfflineQueueSummary> watchQueueSummary() => _isar.offlineTasks
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => getQueueSummary());

  /// Failed/conflict görevleri manuel retry için atomik olarak pending yapar.
  /// Retry sayısı, son hata ve son deneme zamanı audit amacıyla korunur.
  Future<Set<Id>> requeueFailedAndConflicted() async {
    return _isar.writeTxn(() async {
      final tasks = await _isar.offlineTasks.where().findAll();
      final retryable = tasks
          .where(
            (task) =>
                task.status == OfflineTaskStatus.failed ||
                task.status == OfflineTaskStatus.conflict,
          )
          .toList();
      if (retryable.isEmpty) return const <Id>{};

      final now = DateTime.now();
      for (final task in retryable) {
        task
          ..status = OfflineTaskStatus.pending
          ..updatedAt = now;
      }
      await _isar.offlineTasks.putAll(retryable);
      return retryable.map((task) => task.id).toSet();
    });
  }

  /// Manuel retry sırasında yalnız kişisel transaction görevlerini yeniden
  /// kuyruğa alır; grup görevleri kendi coordinator'ı tarafından yönetilir.
  Future<Set<Id>> requeueFailedAndConflictedPersonalTasks() async {
    return _isar.writeTxn(() async {
      final tasks = await _isar.offlineTasks.where().findAll();
      final retryable = tasks
          .where(
            (task) =>
                !task.type.isGroupOperation &&
                (task.status == OfflineTaskStatus.failed ||
                    task.status == OfflineTaskStatus.conflict),
          )
          .toList();
      if (retryable.isEmpty) return const <Id>{};

      final now = DateTime.now();
      for (final task in retryable) {
        task
          ..status = OfflineTaskStatus.pending
          ..updatedAt = now;
      }
      await _isar.offlineTasks.putAll(retryable);
      return retryable.map((task) => task.id).toSet();
    });
  }

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

  Future<void> markAsSynced(Id id) async {
    await _isar.writeTxn(() async {
      final task = await _isar.offlineTasks.get(id);
      if (task == null) return;

      task
        ..status = OfflineTaskStatus.synced
        ..lastError = null
        ..lastAttemptAt = DateTime.now()
        ..updatedAt = DateTime.now();
      await _isar.offlineTasks.put(task);
    });
  }

  /// Görevi kuyrukta tutarak hata ve deneme sayısını atomik günceller.
  Future<void> updateTaskError(Id id, String error) async {
    await _isar.writeTxn(() async {
      final task = await _isar.offlineTasks.get(id);
      if (task == null) return;

      task
        ..status = OfflineTaskStatus.pending
        ..retryCount += 1
        ..lastError = error
        ..lastAttemptAt = DateTime.now()
        ..updatedAt = DateTime.now();
      await _isar.offlineTasks.put(task);
    });
  }

  Future<void> markPermanentlyFailed(Id id, String error) async {
    await _isar.writeTxn(() async {
      final task = await _isar.offlineTasks.get(id);
      if (task == null) return;

      task
        ..status = OfflineTaskStatus.failed
        ..lastError = error
        ..lastAttemptAt = DateTime.now()
        ..updatedAt = DateTime.now();
      await _isar.offlineTasks.put(task);
    });
  }

  Future<void> markConflict(Id id, String error) async {
    await _isar.writeTxn(() async {
      final task = await _isar.offlineTasks.get(id);
      if (task == null) return;

      task
        ..status = OfflineTaskStatus.conflict
        ..lastError = error
        ..lastAttemptAt = DateTime.now()
        ..updatedAt = DateTime.now();
      await _isar.offlineTasks.put(task);
    });
  }

  /// Audit/debug için yakın tarihli kayıtları korur; eski synced kayıtları
  /// küçük transaction'larla temizler.
  Future<int> deleteSyncedBefore(DateTime cutoff, {int limit = 100}) async {
    if (limit <= 0) return 0;
    final ids = await _isar.offlineTasks
        .filter()
        .statusEqualTo(OfflineTaskStatus.synced)
        .updatedAtLessThan(cutoff)
        .limit(limit)
        .idProperty()
        .findAll();
    if (ids.isEmpty) return 0;
    return _isar.writeTxn(() => _isar.offlineTasks.deleteAll(ids));
  }

  Future<bool> delete(Id id) =>
      _isar.writeTxn(() => _isar.offlineTasks.delete(id));
}

typedef PendingTaskRepository = OfflineTaskRepository;
