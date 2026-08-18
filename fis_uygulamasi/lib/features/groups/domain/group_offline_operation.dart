import 'package:finance_database/finance_database.dart';

import 'group_models.dart';

/// Grup verilerinin çevrimdışı kuyrukta desteklediği işlem türleri.
///
/// Settlement kayıtları API sözleşmesine göre immutable olduğu için yalnızca
/// oluşturma işlemi desteklenir. Düzeltmeler yeni bir settlement kaydıyla
/// yapılır; mevcut kayıt güncellenmez veya silinmez.
enum GroupOfflineOperationType {
  groupExpenseCreate,
  groupExpenseUpdate,
  groupExpenseDelete,
  expenseShareCreate,
  expenseShareUpdate,
  expenseShareDelete,
  settlementCreate,
}

/// Offline-first grup işlemlerinin ortak senkronizasyon zarfı.
///
/// [clientRecordId] cihazlar arasında idempotency sağlar, [ownerKey] yerel
/// verinin kullanıcı/cihaz kapsamını belirler, [syncState] ise kaydın bulutla
/// güncel durumunu taşır.
sealed class GroupOfflineOperation {
  GroupOfflineOperation({
    required this.type,
    required String groupId,
    required String clientRecordId,
    required String ownerKey,
    required this.syncState,
    this.syncPayload,
  }) : groupId = _validUuid(groupId, 'groupId'),
       clientRecordId = _validUuid(clientRecordId, 'clientRecordId'),
       ownerKey = _validOwnerKey(ownerKey);

  factory GroupOfflineOperation.fromJson(Map<String, Object?> json) {
    final type = _operationTypeFromJson(
      _requiredString(json, 'operation_type'),
    );
    final common = _OperationCommon.fromJson(json);
    final payload = _requiredMap(json, 'payload');
    final syncPayload = _optionalMap(json, 'sync_payload');

    final operation = switch (type) {
      GroupOfflineOperationType.groupExpenseCreate =>
        GroupExpenseOfflineOperation.create(
          clientRecordId: common.clientRecordId,
          ownerKey: common.ownerKey,
          syncState: common.syncState,
          expense: GroupExpense.fromJson(payload),
          syncPayload: syncPayload,
        ),
      GroupOfflineOperationType.groupExpenseUpdate =>
        GroupExpenseOfflineOperation.update(
          clientRecordId: common.clientRecordId,
          ownerKey: common.ownerKey,
          syncState: common.syncState,
          expense: GroupExpense.fromJson(payload),
        ),
      GroupOfflineOperationType.groupExpenseDelete =>
        GroupExpenseOfflineOperation.delete(
          groupId: common.groupId,
          expenseId: _requiredUuid(payload, 'expense_id'),
          clientRecordId: common.clientRecordId,
          ownerKey: common.ownerKey,
          syncState: common.syncState,
        ),
      GroupOfflineOperationType.expenseShareCreate =>
        ExpenseShareOfflineOperation.create(
          groupId: common.groupId,
          clientRecordId: common.clientRecordId,
          ownerKey: common.ownerKey,
          syncState: common.syncState,
          share: ExpenseShare.fromJson(payload),
        ),
      GroupOfflineOperationType.expenseShareUpdate =>
        ExpenseShareOfflineOperation.update(
          groupId: common.groupId,
          clientRecordId: common.clientRecordId,
          ownerKey: common.ownerKey,
          syncState: common.syncState,
          share: ExpenseShare.fromJson(payload),
        ),
      GroupOfflineOperationType.expenseShareDelete =>
        ExpenseShareOfflineOperation.delete(
          groupId: common.groupId,
          expenseId: _requiredUuid(payload, 'expense_id'),
          userId: _requiredUuid(payload, 'user_id'),
          clientRecordId: common.clientRecordId,
          ownerKey: common.ownerKey,
          syncState: common.syncState,
        ),
      GroupOfflineOperationType.settlementCreate =>
        SettlementOfflineOperation.create(
          clientRecordId: common.clientRecordId,
          ownerKey: common.ownerKey,
          syncState: common.syncState,
          settlement: Settlement.fromJson(payload),
        ),
    };

    if (operation.groupId != common.groupId) {
      throw FormatException(
        'Offline operation group_id ile payload group_id eşleşmiyor.',
      );
    }
    return operation;
  }

  final GroupOfflineOperationType type;
  final String groupId;
  final String clientRecordId;
  final String ownerKey;
  final SyncState syncState;
  final Map<String, Object?>? syncPayload;

  Map<String, Object?> toJson() => <String, Object?>{
    'operation_type': type.name,
    'group_id': groupId,
    'client_record_id': clientRecordId,
    'owner_key': ownerKey,
    'sync_state': syncState.name,
    'payload': payloadToJson(),
    if (syncPayload != null) 'sync_payload': _copyJsonMap(syncPayload!),
  };

  Map<String, Object?> payloadToJson();

  GroupOfflineOperation withSyncState(SyncState syncState);
}

/// GroupExpense create/update/delete işlemlerini tip güvenli biçimde taşır.
final class GroupExpenseOfflineOperation extends GroupOfflineOperation {
  GroupExpenseOfflineOperation._({
    required super.type,
    required super.groupId,
    required String expenseId,
    required super.clientRecordId,
    required super.ownerKey,
    required super.syncState,
    required Map<String, Object?>? expenseSnapshot,
    Map<String, Object?>? syncPayload,
  }) : _syncPayload = syncPayload == null
           ? null
           : _immutableJsonSnapshot(syncPayload),
       assert(
         type == GroupOfflineOperationType.groupExpenseCreate ||
             type == GroupOfflineOperationType.groupExpenseUpdate ||
             type == GroupOfflineOperationType.groupExpenseDelete,
       ),
       assert(
         type == GroupOfflineOperationType.groupExpenseDelete
             ? expenseSnapshot == null
             : expenseSnapshot != null,
       ),
       _expenseSnapshot = expenseSnapshot == null
           ? null
           : _immutableJsonSnapshot(expenseSnapshot),
       expenseId = _validUuid(expenseId, 'expenseId');

  final Map<String, Object?>? _syncPayload;

  @override
  Map<String, Object?>? get syncPayload =>
      _syncPayload == null ? null : _copyJsonMap(_syncPayload);

  factory GroupExpenseOfflineOperation.create({
    required GroupExpense expense,
    required String clientRecordId,
    required String ownerKey,
    SyncState syncState = SyncState.pending,
    Map<String, Object?>? syncPayload,
  }) => GroupExpenseOfflineOperation._(
    type: GroupOfflineOperationType.groupExpenseCreate,
    groupId: expense.groupId,
    expenseId: expense.id,
    clientRecordId: clientRecordId,
    ownerKey: ownerKey,
    syncState: syncState,
    expenseSnapshot: expense.toJson(),
    syncPayload: syncPayload,
  );

  factory GroupExpenseOfflineOperation.update({
    required GroupExpense expense,
    required String clientRecordId,
    required String ownerKey,
    SyncState syncState = SyncState.pending,
    String? expectedUpdatedAt,
  }) => GroupExpenseOfflineOperation._(
    type: GroupOfflineOperationType.groupExpenseUpdate,
    groupId: expense.groupId,
    expenseId: expense.id,
    clientRecordId: clientRecordId,
    ownerKey: ownerKey,
    syncState: syncState,
    expenseSnapshot: expense.toJson(),
    syncPayload: expectedUpdatedAt == null
        ? null
        : <String, Object?>{
            ...expense.toJson(),
            'expected_updated_at': expectedUpdatedAt,
          },
  );

  factory GroupExpenseOfflineOperation.delete({
    required String groupId,
    required String expenseId,
    required String clientRecordId,
    required String ownerKey,
    SyncState syncState = SyncState.pendingDelete,
    String? expectedUpdatedAt,
  }) => GroupExpenseOfflineOperation._(
    type: GroupOfflineOperationType.groupExpenseDelete,
    groupId: groupId,
    expenseId: expenseId,
    clientRecordId: clientRecordId,
    ownerKey: ownerKey,
    syncState: syncState,
    expenseSnapshot: null,
    syncPayload: expectedUpdatedAt == null
        ? null
        : <String, Object?>{
            'group_id': groupId,
            'expense_id': expenseId,
            'expected_updated_at': expectedUpdatedAt,
          },
  );

  final String expenseId;
  final Map<String, Object?>? _expenseSnapshot;

  /// Snapshot'ın dışarıdan değiştirilememesi için her okumada bağımsız model
  /// üretir. Dönen modelin listeleri değiştirilse bile kuyruk payload'ı sabit
  /// kalır.
  GroupExpense? get expense {
    final snapshot = _expenseSnapshot;
    return snapshot == null
        ? null
        : GroupExpense.fromJson(_copyJsonMap(snapshot));
  }

  @override
  Map<String, Object?> payloadToJson() {
    final snapshot = _expenseSnapshot;
    return snapshot == null
        ? <String, Object?>{'group_id': groupId, 'expense_id': expenseId}
        : _copyJsonMap(snapshot);
  }

  @override
  GroupExpenseOfflineOperation withSyncState(SyncState syncState) =>
      GroupExpenseOfflineOperation._(
        type: type,
        groupId: groupId,
        expenseId: expenseId,
        clientRecordId: clientRecordId,
        ownerKey: ownerKey,
        syncState: syncState,
        expenseSnapshot: _expenseSnapshot,
        syncPayload: _syncPayload,
      );
}

/// ExpenseShare create/update/delete işlemlerini tip güvenli biçimde taşır.
final class ExpenseShareOfflineOperation extends GroupOfflineOperation {
  ExpenseShareOfflineOperation._({
    required super.type,
    required super.groupId,
    required String expenseId,
    required String userId,
    required super.clientRecordId,
    required super.ownerKey,
    required super.syncState,
    required this.share,
  }) : assert(
         type == GroupOfflineOperationType.expenseShareCreate ||
             type == GroupOfflineOperationType.expenseShareUpdate ||
             type == GroupOfflineOperationType.expenseShareDelete,
       ),
       assert(
         type == GroupOfflineOperationType.expenseShareDelete
             ? share == null
             : share != null,
       ),
       expenseId = _validUuid(expenseId, 'expenseId'),
       userId = _validUuid(userId, 'userId');

  factory ExpenseShareOfflineOperation.create({
    required String groupId,
    required ExpenseShare share,
    required String clientRecordId,
    required String ownerKey,
    SyncState syncState = SyncState.pending,
  }) => ExpenseShareOfflineOperation._(
    type: GroupOfflineOperationType.expenseShareCreate,
    groupId: groupId,
    expenseId: share.expenseId,
    userId: share.userId,
    clientRecordId: clientRecordId,
    ownerKey: ownerKey,
    syncState: syncState,
    share: share,
  );

  factory ExpenseShareOfflineOperation.update({
    required String groupId,
    required ExpenseShare share,
    required String clientRecordId,
    required String ownerKey,
    SyncState syncState = SyncState.pending,
  }) => ExpenseShareOfflineOperation._(
    type: GroupOfflineOperationType.expenseShareUpdate,
    groupId: groupId,
    expenseId: share.expenseId,
    userId: share.userId,
    clientRecordId: clientRecordId,
    ownerKey: ownerKey,
    syncState: syncState,
    share: share,
  );

  factory ExpenseShareOfflineOperation.delete({
    required String groupId,
    required String expenseId,
    required String userId,
    required String clientRecordId,
    required String ownerKey,
    SyncState syncState = SyncState.pendingDelete,
  }) => ExpenseShareOfflineOperation._(
    type: GroupOfflineOperationType.expenseShareDelete,
    groupId: groupId,
    expenseId: expenseId,
    userId: userId,
    clientRecordId: clientRecordId,
    ownerKey: ownerKey,
    syncState: syncState,
    share: null,
  );

  final String expenseId;
  final String userId;
  final ExpenseShare? share;

  @override
  Map<String, Object?> payloadToJson() =>
      share?.toJson() ??
      <String, Object?>{'expense_id': expenseId, 'user_id': userId};

  @override
  ExpenseShareOfflineOperation withSyncState(SyncState syncState) =>
      ExpenseShareOfflineOperation._(
        type: type,
        groupId: groupId,
        expenseId: expenseId,
        userId: userId,
        clientRecordId: clientRecordId,
        ownerKey: ownerKey,
        syncState: syncState,
        share: share,
      );
}

/// Immutable Settlement kaydının çevrimdışı oluşturma işlemi.
final class SettlementOfflineOperation extends GroupOfflineOperation {
  SettlementOfflineOperation._({
    required super.groupId,
    required super.clientRecordId,
    required super.ownerKey,
    required super.syncState,
    required this.settlement,
  }) : super(type: GroupOfflineOperationType.settlementCreate);

  factory SettlementOfflineOperation.create({
    required Settlement settlement,
    required String clientRecordId,
    required String ownerKey,
    SyncState syncState = SyncState.pending,
  }) => SettlementOfflineOperation._(
    groupId: settlement.groupId,
    clientRecordId: clientRecordId,
    ownerKey: ownerKey,
    syncState: syncState,
    settlement: settlement,
  );

  final Settlement settlement;

  @override
  Map<String, Object?> payloadToJson() => settlement.toJson();

  @override
  SettlementOfflineOperation withSyncState(SyncState syncState) =>
      SettlementOfflineOperation._(
        groupId: groupId,
        clientRecordId: clientRecordId,
        ownerKey: ownerKey,
        syncState: syncState,
        settlement: settlement,
      );
}

final class _OperationCommon {
  const _OperationCommon({
    required this.groupId,
    required this.clientRecordId,
    required this.ownerKey,
    required this.syncState,
  });

  factory _OperationCommon.fromJson(Map<String, Object?> json) =>
      _OperationCommon(
        groupId: _requiredUuid(json, 'group_id'),
        clientRecordId: _requiredUuid(json, 'client_record_id'),
        ownerKey: _requiredOwnerKey(json, 'owner_key'),
        syncState: _syncStateFromJson(_requiredString(json, 'sync_state')),
      );

  final String groupId;
  final String clientRecordId;
  final String ownerKey;
  final SyncState syncState;
}

/// Queue'ya alınan payload'ı kaynak domain nesnesinden tamamen ayırır.
/// İç içe map ve listeler de unmodifiable olduğu için snapshot sınıf içinde
/// yanlışlıkla değiştirilemez.
Map<String, Object?> _immutableJsonSnapshot(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final entry in source.entries)
        entry.key: _immutableJsonValue(entry.value),
    });

Object? _immutableJsonValue(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final entry in value.entries)
        entry.key as String: _immutableJsonValue(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_immutableJsonValue));
  }
  return value;
}

/// JSON çağrısının döndürdüğü map'in değiştirilmesi iç snapshot'a sızmasın
/// diye her serialization için bağımsız bir derin kopya üretir.
Map<String, Object?> _copyJsonMap(
  Map<String, Object?> source,
) => <String, Object?>{
  for (final entry in source.entries) entry.key: _copyJsonValue(entry.value),
};

Object? _copyJsonValue(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: _copyJsonValue(entry.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final item in value) _copyJsonValue(item)];
  }
  return value;
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

String _validUuid(String value, String field) {
  if (!_uuidPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Geçerli bir UUID olmalıdır.');
  }
  return value;
}

String _validOwnerKey(String value) {
  final separator = value.indexOf(':');
  final scope = separator < 0 ? '' : value.substring(0, separator);
  final identity = separator < 0 ? '' : value.substring(separator + 1);
  if ((scope != 'guest' && scope != 'user') || identity.trim().isEmpty) {
    throw ArgumentError.value(
      value,
      'ownerKey',
      '`guest:<installation-id>` veya `user:<user-id>` olmalıdır.',
    );
  }
  return value;
}

String _requiredString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Offline operation "$field" alanı geçersiz.');
  }
  return value;
}

String _requiredUuid(Map<String, Object?> json, String field) {
  final value = _requiredString(json, field);
  if (!_uuidPattern.hasMatch(value)) {
    throw FormatException('Offline operation "$field" alanı UUID olmalıdır.');
  }
  return value;
}

String _requiredOwnerKey(Map<String, Object?> json, String field) {
  final value = _requiredString(json, field);
  try {
    return _validOwnerKey(value);
  } on ArgumentError {
    throw FormatException('Offline operation "$field" alanı geçersiz.');
  }
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! Map) {
    throw FormatException('Offline operation "$field" nesnesi eksik.');
  }
  return Map<String, Object?>.from(value);
}

Map<String, Object?>? _optionalMap(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! Map) {
    throw FormatException('Offline operation "$field" nesnesi geçersiz.');
  }
  return Map<String, Object?>.from(value);
}

GroupOfflineOperationType _operationTypeFromJson(String value) {
  try {
    return GroupOfflineOperationType.values.byName(value);
  } on ArgumentError {
    throw FormatException('Bilinmeyen offline operation türü: $value');
  }
}

SyncState _syncStateFromJson(String value) {
  try {
    return SyncState.values.byName(value);
  } on ArgumentError {
    throw FormatException('Bilinmeyen sync state: $value');
  }
}
