import 'package:isar/isar.dart';

part 'offline_task.g.dart';

enum OfflineTaskType {
  createTransaction,
  updateTransaction,
  deleteTransaction,
  groupExpenseCreate,
  groupExpenseUpdate,
  groupExpenseDelete,
  expenseShareCreate,
  expenseShareUpdate,
  expenseShareDelete,
  settlementCreate,
}

extension OfflineTaskTypeX on OfflineTaskType {
  bool get isGroupOperation => switch (this) {
    OfflineTaskType.groupExpenseCreate ||
    OfflineTaskType.groupExpenseUpdate ||
    OfflineTaskType.groupExpenseDelete ||
    OfflineTaskType.expenseShareCreate ||
    OfflineTaskType.expenseShareUpdate ||
    OfflineTaskType.expenseShareDelete ||
    OfflineTaskType.settlementCreate => true,
    OfflineTaskType.createTransaction ||
    OfflineTaskType.updateTransaction ||
    OfflineTaskType.deleteTransaction => false,
  };
}

enum OfflineTaskStatus { pending, processing, failed, conflict, synced }

/// Bulut senkronizasyonu sırasında çevrimdışı kalan işlemleri kalıcı olarak
/// kuyrukta tutar. JSON payload domain modelinden bağımsız saklandığı için
/// görevler sonraki uygulama açılışında yeniden işlenebilir.
@collection
class OfflineTask {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: false)
  late String clientTaskId;

  @Enumerated(EnumType.name)
  OfflineTaskType type = OfflineTaskType.createTransaction;

  @Enumerated(EnumType.name)
  OfflineTaskStatus status = OfflineTaskStatus.pending;

  late String payloadJson;

  int retryCount = 0;

  String? lastError;

  DateTime? lastAttemptAt;

  late DateTime createdAt;

  late DateTime updatedAt;

  /// Sync sözleşmesinde kullanılan okunabilir alan adları.
  @ignore
  String get actionType => type.name;
  @ignore
  bool get isSynced => status == OfflineTaskStatus.synced;
}

/// Yeni kodun pending-transaction terminolojisini kullanabilmesini sağlarken
/// mevcut Isar collection ve verileriyle geriye uyumluluğu korur.
typedef PendingTransactionEntity = OfflineTask;
