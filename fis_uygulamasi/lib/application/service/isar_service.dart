import 'package:finance_database/finance_database.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Uygulamaya ait Isar başlatma ayrıntılarını veri paketinden ayırır.
class IsarService {
  static Isar? _instance;

  static Future<Isar> getInstance() async {
    if (_instance != null && _instance!.isOpen) return _instance!;

    final directory = await getApplicationDocumentsDirectory();
    final isar = await Isar.open([
      TransactionEntitySchema,
      ReceiptEntitySchema,
      ReceiptLineItemEntitySchema,
      OfflineTaskSchema,
      CategoryEntitySchema,
      SavingsGoalEntitySchema,
      GroupExpenseEntitySchema,
      ExpenseShareEntitySchema,
      GroupSettlementEntitySchema,
    ], directory: directory.path);
    await TransactionRepository(isar).backfillReceiptLinks();
    _instance = isar;
    return isar;
  }
}
