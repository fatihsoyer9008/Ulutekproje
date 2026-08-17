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

  Future<Id> _putExpense(GroupExpenseEntity expense) async {
    final existing = await _isar.groupExpenseEntitys.getByExpenseId(
      expense.expenseId,
    );
    if (existing != null) {
      expense.id = existing.id;
    }
    return _isar.groupExpenseEntitys.put(expense);
  }

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
}
