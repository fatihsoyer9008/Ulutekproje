import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:finance_database/finance_database.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late TransactionRepository repository;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDir = await Directory.systemTemp.createTemp(
      'isar_export_service_test_',
    );
    isar = await Isar.open(
      [
        TransactionEntitySchema,
        ReceiptEntitySchema,
        ReceiptLineItemEntitySchema,
        OfflineTaskSchema,
      ],
      directory: tempDir.path,
      name: 'transaction_export_service_test',
    );
    repository = TransactionRepository(isar);
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await isar.writeTxn(() async {
      await isar.clear();
    });
  });

  TransactionEntity ownedBy(String? ownerKey, String merchantName) =>
      TransactionEntity()
        ..amountInMinor = 1000
        ..category = TransactionCategory.market
        ..date = DateTime(2026, 8, 1)
        ..source = TransactionSource.manual
        ..merchantName = merchantName
        ..ownerKey = ownerKey;

  test('exportJsonString sadece verilen ownerKey\'e ait kayıtları içerir', () async {
    await repository.addTransaction(ownedBy(null, 'Misafir Kaydı'));
    await repository.addTransaction(ownedBy('user:a', 'A Kaydı'));
    await repository.addTransaction(ownedBy('user:b', 'B Kaydı'));

    final json = await TransactionExportService(
      isar,
      ownerKey: 'user:a',
    ).exportJsonString();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final transactions = decoded['transactions'] as List<dynamic>;

    expect(transactions, hasLength(1));
    expect(
      (transactions.single as Map<String, dynamic>)['merchantName'],
      'A Kaydı',
    );
  });

  test('exportCsvString sadece verilen ownerKey\'e ait kayıtları içerir', () async {
    await repository.addTransaction(ownedBy(null, 'Misafir Kaydı'));
    await repository.addTransaction(ownedBy('user:a', 'A Kaydı'));
    await repository.addTransaction(ownedBy('user:b', 'B Kaydı'));

    final csv = await TransactionExportService(
      isar,
      ownerKey: 'user:b',
    ).exportCsvString();

    expect(csv, contains('B Kaydı'));
    expect(csv, isNot(contains('A Kaydı')));
    expect(csv, isNot(contains('Misafir Kaydı')));
  });

  test('exportJsonString misafir (null ownerKey) kapsamını izole eder', () async {
    await repository.addTransaction(ownedBy(null, 'Misafir Kaydı'));
    await repository.addTransaction(ownedBy('user:a', 'A Kaydı'));

    final json = await TransactionExportService(
      isar,
      ownerKey: null,
    ).exportJsonString();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final transactions = decoded['transactions'] as List<dynamic>;

    expect(transactions, hasLength(1));
    expect(
      (transactions.single as Map<String, dynamic>)['merchantName'],
      'Misafir Kaydı',
    );
  });
}
