import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

/// Uygulama başlangıcında açılan tek Isar instance'ı main.dart tarafından
/// override edilir. Böylece bütün repository'ler aynı veritabanını kullanır.
final isarProvider = Provider<Isar>(
  (ref) => throw StateError(
    'isarProvider uygulama başlangıcında override edilmelidir.',
  ),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(isarProvider)),
);

final offlineTaskRepositoryProvider = Provider<OfflineTaskRepository>(
  (ref) => OfflineTaskRepository(ref.watch(isarProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(isarProvider)),
);

final categoriesProvider = StreamProvider<List<CategoryEntity>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAllCategories(),
);
