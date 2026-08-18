import 'dart:convert';

import 'package:isar/isar.dart';

import '../models/group_expense_entity.dart';
import '../models/offline_task.dart';
import '../models/transaction_entity.dart';

/// Grup masrafı ile ona ait sync kuyruğu kaydını aynı Isar transaction'ında
/// yönetir.
class GroupExpenseOfflineRepository {
  GroupExpenseOfflineRepository(this._isar);

  final Isar _isar;

  /// Yalnız cihazda kalacak masrafları kaydeder.
  ///
  /// Pending bir masrafın bu API ile yazılması engellenir; pending kayıtlar
  /// mutlaka [savePendingWithOfflineTask] ile atomik biçimde kuyruklanmalıdır.
  Future<Id> saveLocalOnly(GroupExpenseEntity expense) {
    if (expense.syncState != SyncState.localOnly) {
      throw StateError(
        'Pending grup masrafı OfflineTask olmadan kaydedilemez.',
      );
    }
    return _isar.writeTxn(() => _putExpense(expense));
  }

  /// Masrafı ve offline görevi tek transaction içinde yazar.
  ///
  /// İki yazımdan biri başarısız olduğunda Isar tüm transaction'ı rollback
  /// eder; veritabanında kuyruğu olmayan pending masraf kalmaz.
  Future<Id> savePendingWithOfflineTask(
    GroupExpenseEntity expense,
    OfflineTask task,
  ) {
    _validatePendingPair(expense, task);

    final now = DateTime.now().toUtc();
    task
      ..createdAt = now
      ..updatedAt = now;

    return _isar.writeTxn(() async {
      final expenseId = await _putExpense(expense);
      await _isar.offlineTasks.put(task);
      return expenseId;
    });
  }

  /// Var olan masrafı cihazda tombstone'a çevirip silme görevini aynı
  /// transaction içinde kuyruğa ekler.
  ///
  /// Masrafın ilk create operasyonundaki [GroupExpenseEntity.clientRecordId]
  /// korunur. Silme operasyonunun ayrı idempotency anahtarı [task] üzerinde
  /// tutulur ve payload içindeki `expense_id` ile masrafa bağlanır.
  Future<Id> markPendingDeleteWithOfflineTask({
    required String expenseId,
    required String groupId,
    required String ownerKey,
    required OfflineTask task,
    DateTime? deletedAt,
  }) {
    final payload = _decodePayload(task.payloadJson);
    final nestedPayload = payload['payload'];
    if (!ownerKey.startsWith('user:') ||
        task.type != OfflineTaskType.groupExpenseDelete ||
        task.status != OfflineTaskStatus.pending ||
        payload['operation_type'] != OfflineTaskType.groupExpenseDelete.name ||
        payload['client_record_id'] != task.clientTaskId ||
        payload['group_id'] != groupId ||
        payload['owner_key'] != ownerKey ||
        nestedPayload is! Map ||
        nestedPayload['expense_id'] != expenseId) {
      throw StateError('Geçersiz grup masrafı silme görevi.');
    }

    final now = (deletedAt ?? DateTime.now()).toUtc();
    task
      ..createdAt = now
      ..updatedAt = now;

    return _isar.writeTxn(() async {
      final expense = await _isar.groupExpenseEntitys.getByExpenseId(expenseId);
      if (expense == null ||
          expense.groupId != groupId ||
          expense.ownerKey != ownerKey) {
        throw StateError('Silinecek grup masrafı yerel kapsamda bulunamadı.');
      }
      expense
        ..syncState = SyncState.pendingDelete
        ..deletedAt = now
        ..updatedAt = now
        ..payloadJson = _withTombstone(expense.payloadJson, now);
      await _isar.groupExpenseEntitys.put(expense);
      return _isar.offlineTasks.put(task);
    });
  }

  Future<GroupExpenseEntity?> getByExpenseId(String expenseId) =>
      _isar.groupExpenseEntitys.getByExpenseId(expenseId);

  Future<List<GroupExpenseEntity>> getByGroup({
    required String groupId,
    required String ownerKey,
  }) => _isar.groupExpenseEntitys
      .filter()
      .groupIdEqualTo(groupId)
      .ownerKeyEqualTo(ownerKey)
      .sortByExpenseDateDesc()
      .findAll();

  /// Yalnız grup operasyonlarını oluşturulma sırasıyla döndürür.
  Future<List<OfflineTask>> getPendingSyncTasks({
    required String ownerKey,
    int limit = 50,
  }) async {
    if (limit <= 0) return const [];
    final tasks = await _isar.offlineTasks
        .filter()
        .statusEqualTo(OfflineTaskStatus.pending)
        .sortByCreatedAt()
        .findAll();
    return tasks
        .where((task) {
          if (!task.type.isGroupOperation) return false;
          try {
            return _decodePayload(task.payloadJson)['owner_key'] == ownerKey;
          } on StateError {
            return false;
          }
        })
        .take(limit)
        .toList(growable: false);
  }

  /// Expense dışındaki immutable grup operasyonlarını (örn. settlement)
  /// owner scope'u doğrulandıktan sonra kalıcı kuyruğa ekler.
  Future<Id> enqueueGroupTask(OfflineTask task, {required String ownerKey}) {
    final payload = _decodePayload(task.payloadJson);
    if (!ownerKey.startsWith('user:') || payload['owner_key'] != ownerKey) {
      throw StateError(
        'Grup sync görevi aktif kullanıcı kapsamıyla eşleşmiyor.',
      );
    }
    if (!task.type.isGroupOperation ||
        task.status != OfflineTaskStatus.pending ||
        payload['client_record_id'] != task.clientTaskId) {
      throw StateError('Geçersiz grup sync görevi.');
    }
    final now = DateTime.now().toUtc();
    task
      ..createdAt = now
      ..updatedAt = now;
    return _isar.writeTxn(() => _isar.offlineTasks.put(task));
  }

  /// Failed/conflict grup görevlerini audit alanlarına dokunmadan pending
  /// durumuna getirir. İlgili yerel masraf da tekrar sync edilebilir olur.
  Future<Set<Id>> requeueFailedAndConflictedSyncTasks() {
    return _isar.writeTxn(() async {
      final tasks = await _isar.offlineTasks.where().findAll();
      final retryable = tasks
          .where(
            (task) =>
                task.type.isGroupOperation &&
                (task.status == OfflineTaskStatus.failed ||
                    task.status == OfflineTaskStatus.conflict),
          )
          .toList();
      if (retryable.isEmpty) return const <Id>{};

      final now = DateTime.now().toUtc();
      for (final task in retryable) {
        task
          ..status = OfflineTaskStatus.pending
          ..updatedAt = now;
        await _updateExpenseSyncState(task, _pendingSyncState(task));
      }
      await _isar.offlineTasks.putAll(retryable);
      return retryable.map((task) => task.id).toSet();
    });
  }

  /// Task ve bağlı GroupExpense kaydını aynı transaction içinde synced yapar.
  /// retryCount/lastError/lastAttemptAt audit geçmişi bilinçli olarak korunur.
  Future<void> markSyncTaskAsSynced(Id taskId) =>
      _updateSyncTask(taskId, (task, now) async {
        task
          ..status = OfflineTaskStatus.synced
          ..lastAttemptAt = now
          ..updatedAt = now;
        await _updateExpenseSyncState(task, SyncState.synced);
      });

  /// Geçici hatayı kaydeder ve görev pending kaldığı için sonraki backoff
  /// denemesine izin verir.
  Future<void> recordSyncTaskError(Id taskId, String error) =>
      _updateSyncTask(taskId, (task, now) async {
        task
          ..status = OfflineTaskStatus.pending
          ..retryCount += 1
          ..lastError = error
          ..lastAttemptAt = now
          ..updatedAt = now;
        await _updateExpenseSyncState(task, _pendingSyncState(task));
      });

  Future<void> markSyncTaskFailed(Id taskId, String error) =>
      _updateSyncTask(taskId, (task, now) async {
        task
          ..status = OfflineTaskStatus.failed
          ..lastError = error
          ..lastAttemptAt = now
          ..updatedAt = now;
        await _updateExpenseSyncState(task, SyncState.failed);
      });

  Future<void> markSyncTaskConflict(Id taskId, String error) =>
      _updateSyncTask(taskId, (task, now) async {
        task
          ..status = OfflineTaskStatus.conflict
          ..lastError = error
          ..lastAttemptAt = now
          ..updatedAt = now;
        await _updateExpenseSyncState(task, SyncState.failed);
      });

  /// Pull ile gelen server snapshot'ını yalnız yerelde bekleyen değişiklik yoksa
  /// uygular. Pending/failed kayıtların sessizce ezilmesini engeller.
  Future<bool> saveSyncedFromPull(GroupExpenseEntity expense) {
    if (expense.syncState != SyncState.synced) {
      throw StateError('Pull snapshotı synced durumda olmalıdır.');
    }
    if (!expense.ownerKey.startsWith('user:')) {
      throw StateError('Pull snapshotı kayıtlı kullanıcıya ait olmalıdır.');
    }

    return _isar.writeTxn(() async {
      final existing = await _isar.groupExpenseEntitys.getByExpenseId(
        expense.expenseId,
      );
      if (existing != null && existing.syncState != SyncState.synced) {
        return false;
      }
      if (existing != null) expense.id = existing.id;
      await _isar.groupExpenseEntitys.put(expense);
      return true;
    });
  }

  /// Başka cihazdan pull edilen silmeyi var olan yerel kayda uygular.
  ///
  /// Bekleyen yerel create/update/delete değişikliği varsa tombstone sessizce
  /// uygulanmaz; conflict çözümü için yerel kayıt korunur.
  Future<bool> applyPulledTombstone({
    required String expenseId,
    required String groupId,
    required String ownerKey,
    required DateTime deletedAt,
  }) {
    if (!ownerKey.startsWith('user:')) {
      throw StateError('Pull tombstone kayıtlı kullanıcıya ait olmalıdır.');
    }
    final tombstoneAt = deletedAt.toUtc();
    return _isar.writeTxn(() async {
      final expense = await _isar.groupExpenseEntitys.getByExpenseId(expenseId);
      if (expense == null ||
          expense.groupId != groupId ||
          expense.ownerKey != ownerKey ||
          expense.syncState != SyncState.synced) {
        return false;
      }
      if (expense.deletedAt?.toUtc() == tombstoneAt) return false;
      expense
        ..syncState = SyncState.synced
        ..deletedAt = tombstoneAt
        ..updatedAt = tombstoneAt
        ..payloadJson = _withTombstone(expense.payloadJson, tombstoneAt);
      await _isar.groupExpenseEntitys.put(expense);
      return true;
    });
  }

  Future<Id> _putExpense(GroupExpenseEntity expense) async {
    final existing = await _isar.groupExpenseEntitys.getByExpenseId(
      expense.expenseId,
    );
    if (existing != null) {
      expense.id = existing.id;
    }
    return _isar.groupExpenseEntitys.put(expense);
  }

  Future<void> _updateSyncTask(
    Id taskId,
    Future<void> Function(OfflineTask task, DateTime now) mutate,
  ) {
    return _isar.writeTxn(() async {
      final task = await _isar.offlineTasks.get(taskId);
      if (task == null) return;
      if (!task.type.isGroupOperation) {
        throw StateError('Kişisel task grup sync repository ile yönetilemez.');
      }
      final now = DateTime.now().toUtc();
      await mutate(task, now);
      await _isar.offlineTasks.put(task);
    });
  }

  Future<void> _updateExpenseSyncState(
    OfflineTask task,
    SyncState state,
  ) async {
    final expenseId = await _expenseIdForTask(task);
    if (expenseId == null) return;
    final expense = await _isar.groupExpenseEntitys.getByExpenseId(expenseId);
    if (expense == null) return;
    expense.syncState = state;
    await _isar.groupExpenseEntitys.put(expense);
  }

  Future<String?> _expenseIdForTask(OfflineTask task) async {
    if (task.type == OfflineTaskType.groupExpenseCreate ||
        task.type == OfflineTaskType.groupExpenseUpdate ||
        task.type == OfflineTaskType.groupExpenseDelete) {
      final byClientId = await _isar.groupExpenseEntitys.getByClientRecordId(
        task.clientTaskId,
      );
      if (byClientId != null) return byClientId.expenseId;
    }

    final payload = _decodePayload(task.payloadJson);
    final nested = payload['payload'];
    if (nested is Map && nested['expense_id'] is String) {
      return nested['expense_id']! as String;
    }
    return null;
  }

  SyncState _pendingSyncState(OfflineTask task) =>
      task.type == OfflineTaskType.groupExpenseDelete
      ? SyncState.pendingDelete
      : SyncState.pending;

  void _validatePendingPair(GroupExpenseEntity expense, OfflineTask task) {
    if (!expense.ownerKey.startsWith('user:')) {
      throw StateError('Misafir grup masrafı sync kuyruğuna eklenemez.');
    }
    if (expense.syncState != SyncState.pending &&
        expense.syncState != SyncState.pendingDelete) {
      throw StateError('Kuyruklanan grup masrafı pending durumda olmalıdır.');
    }
    if (!task.type.isGroupOperation) {
      throw ArgumentError.value(
        task.type,
        'task.type',
        'Grup operasyon türü olmalıdır.',
      );
    }
    if (task.status != OfflineTaskStatus.pending) {
      throw StateError('Yeni grup görevi pending durumda olmalıdır.');
    }
    if (expense.clientRecordId != task.clientTaskId) {
      throw StateError('Masraf ve OfflineTask client ID değerleri eşleşmiyor.');
    }

    final payload = _decodePayload(task.payloadJson);
    if (payload['client_record_id'] != expense.clientRecordId ||
        payload['group_id'] != expense.groupId ||
        payload['owner_key'] != expense.ownerKey ||
        payload['operation_type'] != task.type.name) {
      throw StateError('Masraf ile OfflineTask payload alanları eşleşmiyor.');
    }
  }

  Map<String, Object?> _decodePayload(String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException();
      }
      return decoded;
    } on FormatException {
      throw StateError(
        'OfflineTask payloadJson geçerli bir JSON nesnesi değil.',
      );
    }
  }

  String _withTombstone(String payloadJson, DateTime deletedAt) {
    final payload = _decodePayload(payloadJson);
    final timestamp = deletedAt.toUtc().toIso8601String();
    payload
      ..['deleted_at'] = timestamp
      ..['updated_at'] = timestamp;
    return jsonEncode(payload);
  }
}
