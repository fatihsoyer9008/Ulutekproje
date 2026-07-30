import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/offline_task.dart';
import 'models/transaction_entity.dart';

class IsarService {
  static Isar? _instance;

  static Future<Isar> getInstance() async {
    if (_instance != null && _instance!.isOpen) return _instance!;

    final dir = await getApplicationDocumentsDirectory();

    _instance = await Isar.open(
      [TransactionEntitySchema, OfflineTaskSchema],
      directory: dir.path,
    );

    return _instance!;
  }
}
