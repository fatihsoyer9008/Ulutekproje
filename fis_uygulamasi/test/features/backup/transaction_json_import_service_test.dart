import 'package:app_main/features/backup/data/transaction_json_import_service.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'seçilen JSON dosyasını doğrulayıp repository callbackine aktarır',
    () async {
      List<TransactionEntity>? importedTransactions;
      final service = TransactionJsonImportService(
        pickFile: () async => const TransactionJsonFile(
          name: 'islemler.json',
          contents: '''
{
  "schemaVersion": 1,
  "transactions": [
    {
      "transactionType": "expense",
      "amountInMinor": 2500,
      "category": "ulasim",
      "date": "2026-07-30T08:00:00",
      "source": "manual"
    }
  ]
}
''',
        ),
        importTransactions: (transactions) async {
          importedTransactions = transactions;
          return TransactionImportResult(
            selectedCount: transactions.length,
            importedCount: transactions.length,
            skippedDuplicateCount: 0,
          );
        },
      );

      final preview = await service.selectBackup();
      expect(preview, isNotNull);
      expect(preview!.fileName, 'islemler.json');
      expect(preview.transactions, hasLength(1));

      final result = await service.importBackup(preview);
      expect(result.importedCount, 1);
      expect(importedTransactions, hasLength(1));
      expect(importedTransactions!.single.amountInMinor, 2500);
    },
  );

  test('dosya seçimi iptal edilirse import başlatmaz', () async {
    var importCalled = false;
    final service = TransactionJsonImportService(
      pickFile: () async => null,
      importTransactions: (transactions) async {
        importCalled = true;
        return const TransactionImportResult(
          selectedCount: 0,
          importedCount: 0,
          skippedDuplicateCount: 0,
        );
      },
    );

    expect(await service.selectBackup(), isNull);
    expect(importCalled, isFalse);
  });

  test('seçilen CSV dosyasını doğrulayıp içe aktarır', () async {
    List<TransactionEntity>? importedTransactions;
    final service = TransactionJsonImportService(
      pickFile: () async => const TransactionJsonFile(
        name: 'islemler.csv',
        contents:
            '\uFEFFsep=;\r\n'
            'transactionType;amountInMinor;category;date;merchantName;source\r\n'
            'income;12500;diger;2026-07-30T08:00:00;Maaş;manual\r\n',
      ),
      importTransactions: (transactions) async {
        importedTransactions = transactions;
        return TransactionImportResult(
          selectedCount: transactions.length,
          importedCount: transactions.length,
          skippedDuplicateCount: 0,
        );
      },
    );

    final preview = await service.selectBackup();
    expect(preview, isNotNull);
    expect(preview!.format, TransactionImportFormat.csv);
    expect(preview.transactions.single.amountInMinor, 12500);

    await service.importBackup(preview);
    expect(importedTransactions, hasLength(1));
  });

  test('geçersiz JSON repository callbackini çağırmaz', () async {
    var importCalled = false;
    final service = TransactionJsonImportService(
      pickFile: () async =>
          const TransactionJsonFile(name: 'bozuk.json', contents: '{geçersiz'),
      importTransactions: (transactions) async {
        importCalled = true;
        return const TransactionImportResult(
          selectedCount: 0,
          importedCount: 0,
          skippedDuplicateCount: 0,
        );
      },
    );

    await expectLater(
      service.selectBackup(),
      throwsA(isA<TransactionJsonImportException>()),
    );
    expect(importCalled, isFalse);
  });
}
