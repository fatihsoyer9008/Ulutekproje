import 'dart:io';

import 'package:app_main/core/database/database_providers.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'database_providers_test_',
    );
    isar = await Isar.open(
      [TransactionEntitySchema, OfflineTaskSchema],
      directory: tempDirectory.path,
      name: 'database_providers_test',
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('aynı Isar instanceını repository providerlarına sunar', () {
    final container = ProviderContainer(
      overrides: [isarProvider.overrideWithValue(isar)],
    );
    addTearDown(container.dispose);

    expect(container.read(isarProvider), same(isar));
    expect(
      container.read(transactionRepositoryProvider),
      isA<TransactionRepository>(),
    );
    expect(
      container.read(offlineTaskRepositoryProvider),
      isA<OfflineTaskRepository>(),
    );
  });
}
