import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late TransactionRepository repository;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'transaction_import_repository_test_',
    );
    isar = await Isar.open(
      [
        TransactionEntitySchema,
        ReceiptEntitySchema,
        ReceiptLineItemEntitySchema,
      ],
      directory: tempDirectory.path,
      name: 'transaction_import_repository_test',
    );
    repository = TransactionRepository(isar);
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  setUp(() async {
    await isar.writeTxn(isar.clear);
  });

  test('mevcut ve dosya içindeki tekrarları tek transactionda atlar', () async {
    TransactionEntity transaction({required String merchantName}) {
      final timestamp = DateTime(2026, 7, 30, 12);
      return TransactionEntity()
        ..transactionType = TransactionType.expense
        ..amountInMinor = 1250
        ..category = TransactionCategory.market
        ..date = timestamp
        ..merchantName = merchantName
        ..source = TransactionSource.manual
        ..createdAt = timestamp
        ..updatedAt = timestamp;
    }

    await repository.addTransaction(transaction(merchantName: 'Mevcut'));

    final imported = transaction(merchantName: 'Yeni')
      ..receiptLineItems = [
        ReceiptLineItemEntity()
          ..transactionId = 0
          ..position = 0
          ..name = 'İçe aktarılan ürün'
          ..priceInMinor = 1250,
      ]
      ..receiptLineItemsLoaded = true;
    final result = await repository.importTransactions([
      transaction(merchantName: 'Mevcut'),
      imported,
      transaction(merchantName: 'Yeni'),
    ]);

    expect(result.selectedCount, 3);
    expect(result.importedCount, 1);
    expect(result.skippedDuplicateCount, 2);
    final stored = await repository.getAllTransactions();
    expect(stored, hasLength(2));
    expect(
      stored.map((item) => item.merchantName),
      containsAll(['Mevcut', 'Yeni']),
    );
    expect(
      stored
          .singleWhere((item) => item.merchantName == 'Yeni')
          .receiptLineItems,
      hasLength(1),
    );
  });
}
