import 'package:isar/isar.dart';

import '../isar_service.dart';
import '../models/transaction_entity.dart';

class TransactionRepository {
  /// Yeni bir işlemi veritabanına kaydeder.
  Future<void> addTransaction(TransactionEntity transaction) async {
    final isar = await IsarService.getInstance();

    final now = DateTime.now();

    // Yeni kayıt oluşturulurken zaman bilgileri atanır.
    transaction.createdAt = now;
    transaction.updatedAt = now;

    await isar.writeTxn(() async {
      await isar.transactionEntitys.put(transaction);
    });
  }

  /// Veritabanındaki tüm işlemleri getirir.
  Future<List<TransactionEntity>> getAllTransactions() async {
    final isar = await IsarService.getInstance();

    return isar.transactionEntitys.where().findAll();
  }

  /// ID'ye göre tek bir işlemi getirir.
  Future<TransactionEntity?> getTransactionById(int id) async {
    final isar = await IsarService.getInstance();

    return isar.transactionEntitys.get(id);
  }

  /// Mevcut bir işlemi günceller.
  Future<void> updateTransaction(TransactionEntity transaction) async {
    final isar = await IsarService.getInstance();

    transaction.updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.transactionEntitys.put(transaction);
    });
  }

  /// Verilen ID'ye sahip finansal işlemi veritabanından siler.
  Future<void> deleteTransaction(int id) async {
    final isar = await IsarService.getInstance();

    await isar.writeTxn(() async {
      await isar.transactionEntitys.delete(id);
    });
  }
}