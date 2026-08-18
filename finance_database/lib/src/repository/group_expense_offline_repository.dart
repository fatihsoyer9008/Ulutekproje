import 'dart:convert';

import 'package:isar/isar.dart';

import '../models/expense_share_entity.dart';
import '../models/group_expense_entity.dart';
import '../models/group_settlement_entity.dart';
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

  /// UI için aktif masrafları yerel veritabanından canlı olarak yayınlar.
  /// Tombstone kayıtları sync/audit amacıyla saklanır fakat listede gösterilmez.
  Stream<List<GroupExpenseEntity>> watchActiveByGroup({
    required String groupId,
    required String ownerKey,
  }) => _isar.groupExpenseEntitys
      .filter()
      .groupIdEqualTo(groupId)
      .ownerKeyEqualTo(ownerKey)
      .deletedAtIsNull()
      .sortByExpenseDateDesc()
      .watch(fireImmediately: true);

  /// Pull ile gelen ExpenseShare snapshot'ını idempotent biçimde saklar.
  /// Daha yeni bir snapshot veya tombstone eski pull verisiyle ezilmez.
  Future<bool> saveExpenseShareFromPull(ExpenseShareEntity share) {
    _validatePulledShare(share);
    return _isar.writeTxn(() async {
      final existing = await _isar.expenseShareEntitys.getByRecordKey(
        share.recordKey,
      );
      if (existing != null) {
        if (existing.serverUpdatedAt.toUtc().isAfter(
          share.serverUpdatedAt.toUtc(),
        )) {
          return false;
        }
        if (_sameShareSnapshot(existing, share)) return false;
        share.id = existing.id;
      }
      await _isar.expenseShareEntitys.put(share);
      return true;
    });
  }

  /// Pull ile gelen ExpenseShare silmesini kayıt yoksa bile tombstone olarak
  /// saklar. Böylece daha eski create/update snapshot'ları diriltilemez.
  Future<bool> applyExpenseShareTombstoneFromPull({
    required String expenseId,
    required String userId,
    required String groupId,
    required String ownerKey,
    required DateTime deletedAt,
  }) {
    _requirePulledOwner(ownerKey);
    final tombstoneAt = deletedAt.toUtc();
    final recordKey = _expenseShareRecordKey(ownerKey, expenseId, userId);
    return _isar.writeTxn(() async {
      final existing = await _isar.expenseShareEntitys.getByRecordKey(
        recordKey,
      );
      if (existing != null) {
        if (existing.groupId != groupId ||
            existing.expenseId != expenseId ||
            existing.userId != userId ||
            existing.ownerKey != ownerKey) {
          throw StateError('ExpenseShare tombstone kapsamı eşleşmiyor.');
        }
        if (existing.serverUpdatedAt.toUtc().isAfter(tombstoneAt) ||
            (_sameInstant(existing.serverUpdatedAt, tombstoneAt) &&
                existing.deletedAt != null)) {
          return false;
        }
        existing
          ..serverUpdatedAt = tombstoneAt
          ..deletedAt = tombstoneAt;
        await _isar.expenseShareEntitys.put(existing);
        return true;
      }

      await _isar.expenseShareEntitys.put(
        ExpenseShareEntity()
          ..recordKey = recordKey
          ..expenseId = expenseId
          ..userId = userId
          ..groupId = groupId
          ..ownerKey = ownerKey
          ..serverUpdatedAt = tombstoneAt
          ..deletedAt = tombstoneAt,
      );
      return true;
    });
  }

  Future<ExpenseShareEntity?> getExpenseShare({
    required String expenseId,
    required String userId,
    required String ownerKey,
  }) => _isar.expenseShareEntitys.getByRecordKey(
    _expenseShareRecordKey(ownerKey, expenseId, userId),
  );

  Future<List<ExpenseShareEntity>> getActiveExpenseShares({
    required String expenseId,
    required String ownerKey,
  }) => _isar.expenseShareEntitys
      .filter()
      .expenseIdEqualTo(expenseId)
      .ownerKeyEqualTo(ownerKey)
      .deletedAtIsNull()
      .findAll();

  /// Immutable settlement snapshot'ını kullanıcı kapsamında idempotent saklar.
  Future<bool> saveSettlementFromPull(GroupSettlementEntity settlement) {
    _validatePulledSettlement(settlement);
    return _isar.writeTxn(() async {
      final existing = await _isar.groupSettlementEntitys.getByRecordKey(
        settlement.recordKey,
      );
      if (existing != null) {
        if (existing.serverUpdatedAt.toUtc().isAfter(
          settlement.serverUpdatedAt.toUtc(),
        )) {
          return false;
        }
        if (_sameSettlementSnapshot(existing, settlement)) return false;
        settlement.id = existing.id;
      }
      await _isar.groupSettlementEntitys.put(settlement);
      return true;
    });
  }

  Future<List<GroupSettlementEntity>> getSettlementsByGroup({
    required String groupId,
    required String ownerKey,
  }) => _isar.groupSettlementEntitys
      .filter()
      .groupIdEqualTo(groupId)
      .ownerKeyEqualTo(ownerKey)
      .sortByCreatedAtDesc()
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

  Future<List<OfflineTask>> getConflictSyncTasks({
    required String ownerKey,
  }) async {
    final tasks = await _isar.offlineTasks
        .filter()
        .statusEqualTo(OfflineTaskStatus.conflict)
        .sortByUpdatedAtDesc()
        .findAll();
    return tasks
        .where((task) {
          if (task.type != OfflineTaskType.groupExpenseCreate &&
              task.type != OfflineTaskType.groupExpenseUpdate &&
              task.type != OfflineTaskType.groupExpenseDelete) {
            return false;
          }
          try {
            return _decodePayload(task.payloadJson)['owner_key'] == ownerKey;
          } on StateError {
            return false;
          }
        })
        .toList(growable: false);
  }

  Stream<List<OfflineTask>> watchConflictSyncTasks({
    required String ownerKey,
  }) => _isar.offlineTasks
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => getConflictSyncTasks(ownerKey: ownerKey));

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

  /// Bağlantı geri geldiğinde yalnız geçici hata denemesi bulunan ve aktif
  /// kullanıcıya ait failed grup görevlerini yeniden kuyruğa alır.
  Future<Set<Id>> requeueRetryableFailedSyncTasks({required String ownerKey}) {
    return _isar.writeTxn(() async {
      final tasks = await _isar.offlineTasks.where().findAll();
      final retryable = tasks.where((task) {
        if (!task.type.isGroupOperation ||
            task.status != OfflineTaskStatus.failed ||
            task.retryCount <= 0) {
          return false;
        }
        try {
          return _decodePayload(task.payloadJson)['owner_key'] == ownerKey;
        } on StateError {
          return false;
        }
      }).toList();
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

  /// Kullanıcı sunucu sürümünü seçtiğinde conflict taskını kapatır ve yerel
  /// masrafı aynı transaction içinde server snapshotı/tombstone ile değiştirir.
  Future<void> resolveConflictUsingServer({
    required Id conflictTaskId,
    required String ownerKey,
    GroupExpenseEntity? serverExpense,
    DateTime? serverDeletedAt,
  }) {
    if ((serverExpense == null) == (serverDeletedAt == null)) {
      throw ArgumentError(
        'Server snapshotı veya tombstone zamanı seçeneklerinden biri verilmeli.',
      );
    }
    return _isar.writeTxn(() async {
      final task = await _requireConflictTask(conflictTaskId, ownerKey);
      final expenseId = await _expenseIdForTask(task);
      if (expenseId == null) {
        throw StateError('Conflict görevi bir grup masrafına bağlanamadı.');
      }
      final existing = await _isar.groupExpenseEntitys.getByExpenseId(
        expenseId,
      );
      if (serverExpense != null) {
        if (serverExpense.ownerKey != ownerKey ||
            serverExpense.expenseId != expenseId ||
            serverExpense.syncState != SyncState.synced) {
          throw StateError(
            'Server masraf snapshotı conflict kapsamıyla eşleşmiyor.',
          );
        }
        if (existing != null) serverExpense.id = existing.id;
        await _isar.groupExpenseEntitys.put(serverExpense);
      } else {
        if (existing == null || existing.ownerKey != ownerKey) {
          throw StateError('Silinen server masrafının yerel kaydı bulunamadı.');
        }
        final deletedAt = serverDeletedAt!.toUtc();
        existing
          ..syncState = SyncState.synced
          ..deletedAt = deletedAt
          ..updatedAt = deletedAt
          ..payloadJson = _withTombstone(existing.payloadJson, deletedAt);
        await _isar.groupExpenseEntitys.put(existing);
      }
      final now = DateTime.now().toUtc();
      task
        ..status = OfflineTaskStatus.synced
        ..lastAttemptAt = now
        ..updatedAt = now;
      await _isar.offlineTasks.put(task);
    });
  }

  /// Kullanıcı yerel sürümü seçtiğinde eski conflict taskını audit için
  /// kapatır; yeni idempotency anahtarlı task ve pending snapshotı atomik yazar.
  Future<Id> replaceConflictWithPending({
    required Id conflictTaskId,
    required String ownerKey,
    required GroupExpenseEntity replacementExpense,
    required OfflineTask replacementTask,
  }) async {
    _validatePendingPair(replacementExpense, replacementTask);
    final now = DateTime.now().toUtc();
    replacementTask
      ..createdAt = now
      ..updatedAt = now;
    return _isar.writeTxn(() async {
      final conflict = await _requireConflictTask(conflictTaskId, ownerKey);
      final conflictPayload = _decodePayload(conflict.payloadJson);
      final replacementPayload = _decodePayload(replacementTask.payloadJson);
      if (conflictPayload['group_id'] != replacementPayload['group_id'] ||
          replacementPayload['owner_key'] != ownerKey ||
          conflict.clientTaskId == replacementTask.clientTaskId) {
        throw StateError('Replacement task conflict kapsamıyla eşleşmiyor.');
      }
      conflict
        ..status = OfflineTaskStatus.synced
        ..lastAttemptAt = now
        ..updatedAt = now;
      await _isar.offlineTasks.put(conflict);
      await _putExpense(replacementExpense);
      return _isar.offlineTasks.put(replacementTask);
    });
  }

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
      final existingByExpenseId = await _isar.groupExpenseEntitys
          .getByExpenseId(expense.expenseId);
      final existingByClientRecordId = await _isar.groupExpenseEntitys
          .getByClientRecordId(expense.clientRecordId);
      final existingRecords = <GroupExpenseEntity>{
        // ignore: use_null_aware_elements, analyzer sürümü Isar generator'dan yeni
        if (existingByExpenseId != null) existingByExpenseId,
        // ignore: use_null_aware_elements, analyzer sürümü Isar generator'dan yeni
        if (existingByClientRecordId != null) existingByClientRecordId,
      };
      if (existingRecords.any(
        (existing) => existing.syncState != SyncState.synced,
      )) {
        return false;
      }
      if (existingRecords.any(
        (existing) =>
            existing.updatedAt.toUtc().isAfter(expense.updatedAt.toUtc()),
      )) {
        return false;
      }
      final existing = existingByClientRecordId ?? existingByExpenseId;
      if (existingByExpenseId != null &&
          existingByClientRecordId != null &&
          existingByExpenseId.id != existingByClientRecordId.id) {
        await _isar.groupExpenseEntitys.delete(existingByExpenseId.id);
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

  Future<OfflineTask> _requireConflictTask(Id taskId, String ownerKey) async {
    final task = await _isar.offlineTasks.get(taskId);
    if (task == null ||
        task.status != OfflineTaskStatus.conflict ||
        !task.type.isGroupOperation) {
      throw StateError('Çözülecek conflict görevi bulunamadı.');
    }
    final payload = _decodePayload(task.payloadJson);
    if (payload['owner_key'] != ownerKey) {
      throw StateError('Conflict görevi aktif kullanıcıya ait değil.');
    }
    return task;
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

  void _validatePulledShare(ExpenseShareEntity share) {
    _requirePulledOwner(share.ownerKey);
    if (share.recordKey !=
            _expenseShareRecordKey(
              share.ownerKey,
              share.expenseId,
              share.userId,
            ) ||
        share.deletedAt != null ||
        share.payloadJson == null ||
        share.displayName == null ||
        share.amountInMinor == null ||
        share.status == null) {
      throw StateError('Geçersiz ExpenseShare pull snapshotı.');
    }
  }

  void _validatePulledSettlement(GroupSettlementEntity settlement) {
    _requirePulledOwner(settlement.ownerKey);
    if (settlement.recordKey !=
        _settlementRecordKey(settlement.ownerKey, settlement.settlementId)) {
      throw StateError('Geçersiz Settlement pull snapshotı.');
    }
  }

  void _requirePulledOwner(String ownerKey) {
    if (!ownerKey.startsWith('user:')) {
      throw StateError('Pull snapshotı kayıtlı kullanıcıya ait olmalıdır.');
    }
  }

  bool _sameShareSnapshot(ExpenseShareEntity left, ExpenseShareEntity right) =>
      _sameInstant(left.serverUpdatedAt, right.serverUpdatedAt) &&
      left.groupId == right.groupId &&
      left.ownerKey == right.ownerKey &&
      left.expenseId == right.expenseId &&
      left.userId == right.userId &&
      left.displayName == right.displayName &&
      left.amountInMinor == right.amountInMinor &&
      left.status == right.status &&
      _sameNullableInstant(left.settledAt, right.settledAt) &&
      left.payloadJson == right.payloadJson &&
      _sameNullableInstant(left.deletedAt, right.deletedAt);

  bool _sameSettlementSnapshot(
    GroupSettlementEntity left,
    GroupSettlementEntity right,
  ) =>
      _sameInstant(left.serverUpdatedAt, right.serverUpdatedAt) &&
      left.groupId == right.groupId &&
      left.ownerKey == right.ownerKey &&
      left.settlementId == right.settlementId &&
      left.fromUserId == right.fromUserId &&
      left.toUserId == right.toUserId &&
      left.amountInMinor == right.amountInMinor &&
      left.currency == right.currency &&
      _sameInstant(left.settledAt, right.settledAt) &&
      left.note == right.note &&
      _sameInstant(left.createdAt, right.createdAt) &&
      left.payloadJson == right.payloadJson;

  bool _sameInstant(DateTime left, DateTime right) =>
      left.toUtc() == right.toUtc();

  bool _sameNullableInstant(DateTime? left, DateTime? right) =>
      left == null || right == null ? left == right : _sameInstant(left, right);

  String _expenseShareRecordKey(
    String ownerKey,
    String expenseId,
    String userId,
  ) => '$ownerKey|$expenseId|$userId';

  String _settlementRecordKey(String ownerKey, String settlementId) =>
      '$ownerKey|$settlementId';
}
