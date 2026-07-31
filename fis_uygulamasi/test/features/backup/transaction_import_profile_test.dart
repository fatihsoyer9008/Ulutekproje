import 'package:app_main/features/auth/presentation/views/profile_page.dart';
import 'package:app_main/features/backup/data/transaction_json_import_service.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('kullanıcı onayından sonra JSON yedeğini içe aktarır', (
    tester,
  ) async {
    var importCallCount = 0;
    final service = TransactionJsonImportService(
      pickFile: () async => const TransactionJsonFile(
        name: 'yedek.json',
        contents: '''
{
  "schemaVersion": 1,
  "transactions": [
    {
      "transactionType": "expense",
      "amountInMinor": 1000,
      "category": "market",
      "date": "2026-07-30T08:00:00",
      "source": "manual"
    }
  ]
}
''',
      ),
      importTransactions: (transactions) async {
        importCallCount++;
        return TransactionImportResult(
          selectedCount: transactions.length,
          importedCount: transactions.length,
          skippedDuplicateCount: 0,
        );
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProfilePage(transactionImportService: service),
        ),
      ),
    );

    final importButton = find.byKey(const Key('transaction_import_button'));
    expect(find.text('JSON / CSV Yedeğini İçe Aktar'), findsOneWidget);
    expect(
      find.byKey(const Key('transaction_export_json_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transaction_export_csv_button')),
      findsOneWidget,
    );
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('JSON yedeği içe aktarılsın mı?'), findsOneWidget);
    expect(importCallCount, 0);

    await tester.tap(
      find.byKey(const Key('confirm_transaction_import_button')),
    );
    await tester.pumpAndSettle();

    expect(importCallCount, 1);
    expect(find.text('1 işlem içe aktarıldı.'), findsOneWidget);
  });
}
