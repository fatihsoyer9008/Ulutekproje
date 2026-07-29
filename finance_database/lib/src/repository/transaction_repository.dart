import 'package:isar/isar.dart';
import '../models/transaction_entity.dart';

class TransactionRepository {
  /// Isar veritabanı örneği dışarıdan enjekte ediliyor (Dependency Injection)
  TransactionRepository(this._isar);

  final Isar _isar;

  /// Yeni bir işlemi veritabanına kaydeder.
  Future<Id> addTransaction(TransactionEntity transaction) async {
    final now = DateTime.now();
    transaction.createdAt = now;
    transaction.updatedAt = now;

    return await _isar.writeTxn(() async {
      return await _isar.transactionEntitys.put(transaction);
    });
  }

  /// Veritabanındaki tüm işlemleri getirir.
  Future<List<TransactionEntity>> getAllTransactions() async {
    return await _isar.transactionEntitys.where().findAll();
  }

  /// Mevcut işlemleri ve veritabanındaki sonraki değişiklikleri yayınlar.
  Stream<List<TransactionEntity>> watchAllTransactions() {
    return _isar.transactionEntitys.where().watch(fireImmediately: true);
  }

  /// ID'ye göre tek bir işlemi getirir.
  Future<TransactionEntity?> getTransactionById(Id id) async {
    return await _isar.transactionEntitys.get(id);
  }

  /// Mevcut bir işlemi günceller.
  Future<void> updateTransaction(TransactionEntity transaction) async {
    transaction.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.transactionEntitys.put(transaction);
    });
  }

  /// Verilen ID'ye sahip finansal işlemi veritabanından siler.
  Future<bool> deleteTransaction(Id id) async {
    return await _isar.writeTxn(() async {
      return await _isar.transactionEntitys.delete(id);
    });
  }
}
