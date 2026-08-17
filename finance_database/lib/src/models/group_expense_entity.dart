import 'package:isar/isar.dart';

import 'transaction_entity.dart';

part 'group_expense_entity.g.dart';

/// Grup masrafının cihazdaki kalıcı kopyası.
///
/// Sık kullanılan üst alanlar sorgulanabilir kolonlarda, paylar ve kalem
/// atamaları dahil sözleşmenin tamamı ise [payloadJson] snapshot'ında tutulur.
/// Böylece finance_database Flutter domain katmanına bağımlı olmaz.
@collection
class GroupExpenseEntity {
  Id id = Isar.autoIncrement;

  /// API ve cihaz arasında masrafı tekil olarak tanımlayan UUID.
  @Index(unique: true, replace: false)
  late String expenseId;

  @Index()
  late String groupId;

  /// Offline operasyonun idempotency anahtarı olan UUID.
  @Index(unique: true, replace: false)
  late String clientRecordId;

  /// `user:<user-id>` veya yalnız yerel kayıtta `guest:<installation-id>`.
  @Index()
  late String ownerKey;

  String? receiptId;
  late String payerUserId;
  String? createdBy;
  late String title;
  String? note;
  late DateTime expenseDate;
  late int totalAmountInMinor;
  late String currency;
  late String splitType;
  bool isFinanciallyLocked = false;

  @Enumerated(EnumType.name)
  SyncState syncState = SyncState.localOnly;

  /// GroupExpense API sözleşmesinin kayıpsız JSON snapshot'ı.
  late String payloadJson;

  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;
}
