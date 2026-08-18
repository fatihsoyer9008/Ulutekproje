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
    final result = await repository.importTransactions(
      [
        transaction(merchantName: 'Mevcut'),
        imported,
        transaction(merchantName: 'Yeni'),
      ],
      ownerKey: null,
    );

    expect(result.selectedCount, 3);
    expect(result.importedCount, 1);
    expect(result.skippedDuplicateCount, 2);
    final stored = await repository.getAllTransactions(ownerKey: null);
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

  test(
    'içe aktarma ownerKey\'i içe aktaran oturuma göre üzerine yazar ve '
    'tekrar kontrolü sadece o kapsamda çalışır',
    () async {
      TransactionEntity transaction({
        required String merchantName,
        String? ownerKey,
      }) {
        final timestamp = DateTime(2026, 7, 30, 12);
        return TransactionEntity()
          ..transactionType = TransactionType.expense
          ..amountInMinor = 1250
          ..category = TransactionCategory.market
          ..date = timestamp
          ..merchantName = merchantName
          ..source = TransactionSource.manual
          ..createdAt = timestamp
          ..updatedAt = timestamp
          ..ownerKey = ownerKey;
      }

      // user:a'da zaten aynı işlem var; user:b bunu içe aktarınca tekrar
      // sayılmamalı (izole tekrar kontrolü) ve kaydın owner'ı user:b olmalı
      // (yedek dosyasındaki eski ownerKey yok sayılmalı).
      await repository.addTransaction(
        transaction(merchantName: 'Ortak Market', ownerKey: 'user:a'),
      );

      final backupFromAnotherDevice = transaction(
        merchantName: 'Ortak Market',
        ownerKey: 'user:a',
      );

      final result = await repository.importTransactions(
        [backupFromAnotherDevice],
        ownerKey: 'user:b',
      );

      expect(result.importedCount, 1);
      expect(result.skippedDuplicateCount, 0);

      final userBTransactions = await repository.getAllTransactions(
        ownerKey: 'user:b',
      );
      expect(userBTransactions, hasLength(1));
      expect(userBTransactions.single.ownerKey, 'user:b');

      final userATransactions = await repository.getAllTransactions(
        ownerKey: 'user:a',
      );
      expect(userATransactions, hasLength(1));
    },
  );
}
