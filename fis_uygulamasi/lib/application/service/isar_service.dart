import 'package:finance_database/finance_database.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Uygulamaya ait Isar başlatma ayrıntılarını veri paketinden ayırır.
class IsarService {
  static Isar? _instance;

  static Future<Isar> getInstance() async {
    if (_instance != null && _instance!.isOpen) return _instance!;

    final directory = await getApplicationDocumentsDirectory();
    _instance = await Isar.open([
      TransactionEntitySchema,
      ReceiptEntitySchema,
      ReceiptLineItemEntitySchema,
      OfflineTaskSchema,
      CategoryEntitySchema,
    ], directory: directory.path);
    return _instance!;
  }
}
