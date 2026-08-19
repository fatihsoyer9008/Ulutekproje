import 'dart:convert';

import 'package:finance_database/finance_database.dart';
import 'package:isar/isar.dart';

import '../data/group_offline_operation_mapper.dart';
import '../data/group_repository.dart';
import '../data/group_sync_gateway.dart';
import '../domain/group_models.dart';
import '../domain/group_offline_operation.dart';

typedef ConflictRequestIdFactory = String Function();

class GroupExpenseConflict {
  const GroupExpenseConflict({
    required this.taskId,
    required this.operation,
    required this.localExpense,
    required this.code,
    required this.message,
  });

  final Id taskId;
  final GroupExpenseOfflineOperation operation;
  final GroupExpense? localExpense;
  final String? code;
  final String message;

  bool get canKeepLocal => switch (code) {
    'expense_financially_locked' ||
    'expense_locked_by_settlement' ||
    'expense_soft_deleted' ||
    'record_soft_deleted' => false,
    _ => true,
  };
}

abstract interface class GroupExpenseConflictResolver {
  Stream<List<GroupExpenseConflict>> watch({required String ownerKey});

  Future<void> useServerVersion(
    GroupExpenseConflict conflict, {
    required String ownerKey,
  });

  Future<void> keepLocalVersion(
    GroupExpenseConflict conflict, {
    required String ownerKey,
  });
}

class GroupExpenseConflictService implements GroupExpenseConflictResolver {
  const GroupExpenseConflictService(
    this._local,
    this._remote,
    this._requestId, [
    this._triggerSynchronization,
  ]);

  final GroupExpenseOfflineRepository _local;
  final GroupExpenseRepository _remote;
  final ConflictRequestIdFactory _requestId;
  final Future<void> Function()? _triggerSynchronization;

  @override
  Stream<List<GroupExpenseConflict>> watch({required String ownerKey}) => _local
      .watchConflictSyncTasks(ownerKey: ownerKey)
      .asyncMap((tasks) => _toConflicts(tasks));

  @override
  Future<void> useServerVersion(
    GroupExpenseConflict conflict, {
    required String ownerKey,
  }) async {
    _requireOwner(conflict, ownerKey);
    final remoteExpense = await _findRemoteExpense(conflict.operation);
    if (remoteExpense == null) {
      await _local.resolveConflictUsingServer(
        conflictTaskId: conflict.taskId,
        ownerKey: ownerKey,
        serverDeletedAt: DateTime.now().toUtc(),
      );
    } else {
      final entity = GroupExpenseOfflineOperation.create(
        expense: remoteExpense,
        clientRecordId: remoteExpense.id,
        ownerKey: ownerKey,
        syncState: SyncState.synced,
      ).toGroupExpenseEntity();
      await _local.resolveConflictUsingServer(
        conflictTaskId: conflict.taskId,
        ownerKey: ownerKey,
        serverExpense: entity,
      );
    }
    await _triggerSynchronization?.call();
  }

  @override
  Future<void> keepLocalVersion(
    GroupExpenseConflict conflict, {
    required String ownerKey,
  }) async {
    _requireOwner(conflict, ownerKey);
    if (!conflict.canKeepLocal) {
      throw StateError('Bu çakışmada yerel sürüm güvenli biçimde uygulanamaz.');
    }

    final operation = conflict.operation;
    final remoteExpense = await _findRemoteExpense(operation);
    if (remoteExpense == null &&
        operation.type != GroupOfflineOperationType.groupExpenseCreate) {
      throw StateError(
        'Masraf sunucuda silinmiş. Sunucu sürümünü kullanarak devam edin.',
      );
    }

    final localExpense = conflict.localExpense;
    if (localExpense == null) {
      throw StateError('Yerel masraf snapshotı bulunamadı.');
    }
    final newClientRecordId = _requestId();
    late final GroupExpenseOfflineOperation replacement;
    late final GroupExpenseEntity replacementEntity;

    if (operation.type == GroupOfflineOperationType.groupExpenseDelete) {
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      final tombstone = _copyExpense(
        localExpense,
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );
      replacement = GroupExpenseOfflineOperation.delete(
        groupId: operation.groupId,
        expenseId: operation.expenseId,
        clientRecordId: newClientRecordId,
        ownerKey: ownerKey,
        expectedUpdatedAt: remoteExpense?.updatedAt,
      );
      replacementEntity = GroupExpenseOfflineOperation.create(
        expense: tombstone,
        clientRecordId: newClientRecordId,
        ownerKey: ownerKey,
        syncState: SyncState.pendingDelete,
      ).toGroupExpenseEntity();
    } else if (remoteExpense == null) {
      replacement = GroupExpenseOfflineOperation.create(
        expense: localExpense,
        clientRecordId: newClientRecordId,
        ownerKey: ownerKey,
      );
      replacementEntity = replacement.toGroupExpenseEntity();
    } else {
      replacement = GroupExpenseOfflineOperation.update(
        expense: localExpense,
        clientRecordId: newClientRecordId,
        ownerKey: ownerKey,
        expectedUpdatedAt: remoteExpense.updatedAt,
      );
      replacementEntity = replacement.toGroupExpenseEntity();
    }

    await _local.replaceConflictWithPending(
      conflictTaskId: conflict.taskId,
      ownerKey: ownerKey,
      replacementExpense: replacementEntity,
      replacementTask: replacement.toOfflineTask(),
    );
    await _triggerSynchronization?.call();
  }

  Future<List<GroupExpenseConflict>> _toConflicts(
    List<OfflineTask> tasks,
  ) async {
    final result = <GroupExpenseConflict>[];
    for (final task in tasks) {
      final decoded = jsonDecode(task.payloadJson);
      if (decoded is! Map) continue;
      final operation = GroupOfflineOperation.fromJson(
        Map<String, Object?>.from(decoded),
      );
      if (operation is! GroupExpenseOfflineOperation) continue;
      final localEntity = await _local.getByExpenseId(operation.expenseId);
      final error = _decodeError(task.lastError);
      result.add(
        GroupExpenseConflict(
          taskId: task.id,
          operation: operation,
          localExpense: operation.expense ?? localEntity?.toGroupExpense(),
          code: error.code,
          message: error.message,
        ),
      );
    }
    return List<GroupExpenseConflict>.unmodifiable(result);
  }

  Future<GroupExpense?> _findRemoteExpense(
    GroupExpenseOfflineOperation operation,
  ) async {
    final expenses = await _remote.listExpenses(operation.groupId);
    return expenses
        .where((expense) => expense.id == operation.expenseId)
        .firstOrNull;
  }

  void _requireOwner(GroupExpenseConflict conflict, String ownerKey) {
    if (!ownerKey.startsWith('user:') ||
        conflict.operation.ownerKey != ownerKey) {
      throw StateError('Conflict aktif kullanıcı kapsamıyla eşleşmiyor.');
    }
  }

  static _ConflictError _decodeError(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _ConflictError(null, safeGroupSyncConflictMessage(null));
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final rawCode = decoded['code'];
        final code = rawCode is String ? rawCode : null;
        return _ConflictError(code, safeGroupSyncConflictMessage(code));
      }
    } on FormatException {
      // Eski düz metin kayıtlar güvenli genel mesaja dönüştürülür.
    }
    return _ConflictError(null, safeGroupSyncConflictMessage(null));
  }

  static GroupExpense _copyExpense(
    GroupExpense source, {
    required String updatedAt,
    required String? deletedAt,
  }) => GroupExpense(
    id: source.id,
    groupId: source.groupId,
    receiptId: source.receiptId,
    payerUserId: source.payerUserId,
    createdBy: source.createdBy,
    title: source.title,
    note: source.note,
    expenseDate: source.expenseDate,
    totalAmountInMinor: source.totalAmountInMinor,
    currency: source.currency,
    splitType: source.splitType,
    isFinanciallyLocked: source.isFinanciallyLocked,
    shares: source.shares,
    lineItemAssignments: source.lineItemAssignments,
    extraAmounts: source.extraAmounts,
    createdAt: source.createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

class _ConflictError {
  const _ConflictError(this.code, this.message);

  final String? code;
  final String message;
}
