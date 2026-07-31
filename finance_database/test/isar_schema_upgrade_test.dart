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
      [TransactionEntitySchema],
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
    await previousDatabase.writeTxn(
      () => previousDatabase.transactionEntitys.put(transaction),
    );
    await previousDatabase.close();

    final upgradedDatabase = await Isar.open(
      [TransactionEntitySchema, OfflineTaskSchema, CategoryEntitySchema],
      directory: directory.path,
      name: databaseName,
    );

    expect(await upgradedDatabase.transactionEntitys.count(), 1);
    expect(
      (await upgradedDatabase.transactionEntitys.where().findFirst())
          ?.amountInMinor,
      2550,
    );
    expect(await upgradedDatabase.offlineTasks.count(), 0);
    expect(await upgradedDatabase.categoryEntitys.count(), 0);

    await upgradedDatabase.close(deleteFromDisk: true);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
}
