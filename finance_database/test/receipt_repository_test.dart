import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory directory;
  late Isar isar;
  late ReceiptRepository repository;

  setUpAll(() async => Isar.initializeIsarCore(download: true));

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('receipt_repository_');
    isar = await Isar.open(
      [ReceiptEntitySchema, ReceiptLineItemEntitySchema],
      directory: directory.path,
      name: 'receipt_repository_test',
    );
    repository = ReceiptRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('fişi ve ürün kalemlerini tek kayıt akışında saklar', () async {
    final receiptId = await repository.addDraft(
      TransactionDraft(
        institutionName: 'Migros',
        category: 'Market',
        amountInMinor: 2550,
        transactionDate: DateTime(2026, 8, 3),
        rawOcrText: 'MIGROS',
        lineItems: const [
          ReceiptLineItemDraft(
            name: 'Süt 1L',
            totalAmountInMinor: 1200,
            quantityInMillis: 1000,
            unitPriceInMinor: 1200,
            taxRateInBasisPoints: 1000,
          ),
          ReceiptLineItemDraft(name: 'Ekmek', totalAmountInMinor: 1350),
        ],
      ),
    );

    final receipt = await repository.getReceipt(receiptId);
    final items = await repository.getLineItems(receiptId);

    expect(receipt?.merchantName, 'Migros');
    expect(receipt?.totalAmountInMinor, 2550);
    expect(items, hasLength(2));
    expect(items.every((item) => item.receiptId == receiptId), isTrue);
    expect(
      items.firstWhere((item) => item.name == 'Süt 1L').unitPriceInMinor,
      1200,
    );
  });

  test('fiş silindiğinde bağlı ürün kalemlerini de siler', () async {
    final receiptId = await repository.addDraft(
      const TransactionDraft(
        institutionName: 'Market',
        category: 'Market',
        amountInMinor: 1000,
        lineItems: [
          ReceiptLineItemDraft(name: 'Ürün', totalAmountInMinor: 1000),
        ],
      ),
    );

    await repository.deleteReceipt(receiptId);

    expect(await repository.getReceipt(receiptId), isNull);
    expect(await repository.getLineItems(receiptId), isEmpty);
  });
}
