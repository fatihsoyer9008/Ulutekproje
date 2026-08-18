import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  test('yeni şemalar eklenirken mevcut transaction verisini korur', () async {
    await Isar.initializeIsarCore(download: true);
    final directory = await Directory.systemTemp.createTemp(
      'isar_schema_upgrade_test_',
    );
    const databaseName = 'schema_upgrade_test';

    final previousDatabase = await Isar.open(
      [TransactionEntitySchema, ReceiptLineItemEntitySchema],
      directory: directory.path,
      name: databaseName,
    );
    final transaction = TransactionEntity()
      ..amountInMinor = 2550
      ..category = TransactionCategory.market
      ..date = DateTime(2026, 7, 30)
      ..source = TransactionSource.manual
      ..createdAt = DateTime(2026, 7, 30)
      ..updatedAt = DateTime(2026, 7, 30);
    await previousDatabase.writeTxn(() async {
      final transactionId = await previousDatabase.transactionEntitys.put(
        transaction,
      );
      await previousDatabase.receiptLineItemEntitys.put(
        ReceiptLineItemEntity()
          ..transactionId = transactionId
          ..receiptId = 0
          ..position = 0
          ..name = 'Süt',
      );
    });
    await previousDatabase.close();

    final upgradedDatabase = await Isar.open(
      [
        TransactionEntitySchema,
        ReceiptEntitySchema,
        ReceiptLineItemEntitySchema,
        OfflineTaskSchema,
        CategoryEntitySchema,
        SavingsGoalEntitySchema,
        GroupExpenseEntitySchema,
        ExpenseShareEntitySchema,
        GroupSettlementEntitySchema,
      ],
      directory: directory.path,
      name: databaseName,
    );
    await TransactionRepository(upgradedDatabase).backfillReceiptLinks();

    expect(await upgradedDatabase.transactionEntitys.count(), 1);
    expect(
      (await upgradedDatabase.transactionEntitys.where().findFirst())
          ?.amountInMinor,
      2550,
    );
    expect(await upgradedDatabase.offlineTasks.count(), 0);
    expect(await upgradedDatabase.categoryEntitys.count(), 0);
    expect(await upgradedDatabase.savingsGoalEntitys.count(), 0);
    expect(await upgradedDatabase.groupExpenseEntitys.count(), 0);
    expect(await upgradedDatabase.expenseShareEntitys.count(), 0);
    expect(await upgradedDatabase.groupSettlementEntitys.count(), 0);
    expect(await upgradedDatabase.receiptEntitys.count(), 1);
    expect(await upgradedDatabase.receiptLineItemEntitys.count(), 1);
    final receipt = await upgradedDatabase.receiptEntitys.where().findFirst();
    final lineItem = await upgradedDatabase.receiptLineItemEntitys
        .where()
        .findFirst();
    expect(lineItem?.receiptId, receipt?.id);

    await upgradedDatabase.close(deleteFromDisk: true);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
}
