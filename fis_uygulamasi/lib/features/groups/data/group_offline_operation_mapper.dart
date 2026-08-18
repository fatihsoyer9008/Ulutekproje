import 'dart:convert';

import 'package:finance_database/finance_database.dart';

import '../domain/group_models.dart';
import '../domain/group_offline_operation.dart';

extension GroupOfflineOperationPersistenceMapper on GroupOfflineOperation {
  /// Task 6.1 zarfını kayıpsız biçimde OfflineTask payload'ına dönüştürür.
  OfflineTask toOfflineTask() => OfflineTask()
    ..clientTaskId = clientRecordId
    ..type = _offlineTaskType(type)
    ..status = _offlineTaskStatus(syncState)
    ..payloadJson = jsonEncode(toJson());
}

extension GroupExpenseOperationPersistenceMapper
    on GroupExpenseOfflineOperation {
  GroupExpenseEntity toGroupExpenseEntity() {
    final groupExpense = expense;
    if (groupExpense == null) {
      throw StateError('Silme operasyonundan yeni grup masrafı üretilemez.');
    }
    final json = groupExpense.toJson();
    return GroupExpenseEntity()
      ..expenseId = groupExpense.id
      ..groupId = groupExpense.groupId
      ..clientRecordId = clientRecordId
      ..ownerKey = ownerKey
      ..receiptId = groupExpense.receiptId
      ..payerUserId = groupExpense.payerUserId
      ..createdBy = groupExpense.createdBy
      ..title = groupExpense.title
      ..note = groupExpense.note
      ..expenseDate = DateTime.parse(groupExpense.expenseDate).toUtc()
      ..totalAmountInMinor = groupExpense.totalAmountInMinor
      ..currency = groupExpense.currency
      ..splitType = json['split_type']! as String
      ..isFinanciallyLocked = groupExpense.isFinanciallyLocked
      ..syncState = syncState
      ..payloadJson = jsonEncode(json)
      ..createdAt = DateTime.parse(groupExpense.createdAt).toUtc()
      ..updatedAt = DateTime.parse(groupExpense.updatedAt).toUtc()
      ..deletedAt = groupExpense.deletedAt == null
          ? null
          : DateTime.parse(groupExpense.deletedAt!).toUtc();
  }
}

extension GroupExpenseEntityDomainMapper on GroupExpenseEntity {
  GroupExpense toGroupExpense() {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw const FormatException('Yerel grup masrafı snapshotı geçersiz.');
    }
    return GroupExpense.fromJson(Map<String, Object?>.from(decoded));
  }
}

extension ExpenseShareOperationPersistenceMapper
    on ExpenseShareOfflineOperation {
  ExpenseShareEntity toExpenseShareEntity({required DateTime serverUpdatedAt}) {
    final snapshot = share;
    if (snapshot == null) {
      throw StateError(
        'Silme operasyonundan ExpenseShare snapshotı üretilemez.',
      );
    }
    final json = snapshot.toJson();
    return ExpenseShareEntity()
      ..recordKey = '$ownerKey|${snapshot.expenseId}|${snapshot.userId}'
      ..expenseId = snapshot.expenseId
      ..userId = snapshot.userId
      ..groupId = groupId
      ..ownerKey = ownerKey
      ..displayName = snapshot.displayName
      ..amountInMinor = snapshot.amountInMinor
      ..status = snapshot.status.name
      ..settledAt = snapshot.settledAt == null
          ? null
          : DateTime.parse(snapshot.settledAt!).toUtc()
      ..payloadJson = jsonEncode(json)
      ..serverUpdatedAt = serverUpdatedAt.toUtc();
  }
}

extension ExpenseShareEntityDomainMapper on ExpenseShareEntity {
  ExpenseShare? toExpenseShare() {
    final snapshot = payloadJson;
    if (deletedAt != null || snapshot == null) return null;
    final decoded = jsonDecode(snapshot);
    if (decoded is! Map) {
      throw const FormatException('Yerel masraf payı snapshotı geçersiz.');
    }
    return ExpenseShare.fromJson(Map<String, Object?>.from(decoded));
  }
}

extension SettlementOperationPersistenceMapper on SettlementOfflineOperation {
  GroupSettlementEntity toGroupSettlementEntity({
    required DateTime serverUpdatedAt,
  }) {
    final json = settlement.toJson();
    return GroupSettlementEntity()
      ..recordKey = '$ownerKey|${settlement.id}'
      ..settlementId = settlement.id
      ..groupId = settlement.groupId
      ..ownerKey = ownerKey
      ..fromUserId = settlement.fromUserId
      ..toUserId = settlement.toUserId
      ..amountInMinor = settlement.amountInMinor
      ..currency = settlement.currency
      ..settledAt = DateTime.parse(settlement.settledAt).toUtc()
      ..note = settlement.note
      ..createdAt = DateTime.parse(settlement.createdAt).toUtc()
      ..payloadJson = jsonEncode(json)
      ..serverUpdatedAt = serverUpdatedAt.toUtc();
  }
}

extension GroupSettlementEntityDomainMapper on GroupSettlementEntity {
  Settlement toSettlement() {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw const FormatException('Yerel settlement snapshotı geçersiz.');
    }
    return Settlement.fromJson(Map<String, Object?>.from(decoded));
  }
}

OfflineTaskType _offlineTaskType(GroupOfflineOperationType type) =>
    switch (type) {
      GroupOfflineOperationType.groupExpenseCreate =>
        OfflineTaskType.groupExpenseCreate,
      GroupOfflineOperationType.groupExpenseUpdate =>
        OfflineTaskType.groupExpenseUpdate,
      GroupOfflineOperationType.groupExpenseDelete =>
        OfflineTaskType.groupExpenseDelete,
      GroupOfflineOperationType.expenseShareCreate =>
        OfflineTaskType.expenseShareCreate,
      GroupOfflineOperationType.expenseShareUpdate =>
        OfflineTaskType.expenseShareUpdate,
      GroupOfflineOperationType.expenseShareDelete =>
        OfflineTaskType.expenseShareDelete,
      GroupOfflineOperationType.settlementCreate =>
        OfflineTaskType.settlementCreate,
    };

OfflineTaskStatus _offlineTaskStatus(SyncState state) => switch (state) {
  SyncState.pending ||
  SyncState.pendingDelete ||
  SyncState.localOnly => OfflineTaskStatus.pending,
  SyncState.failed => OfflineTaskStatus.failed,
  SyncState.synced => OfflineTaskStatus.synced,
};
