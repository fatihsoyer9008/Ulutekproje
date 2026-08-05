import 'package:app_main/src/screens/transactions_screen.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('search normalizes Turkish merchant and category names', (
    tester,
  ) async {
    await _pumpTransactions(tester, [
      _transaction(merchant: 'İGDAŞ', category: TransactionCategory.fatura),
      _transaction(
        merchant: 'Otobüs Kartı',
        category: TransactionCategory.ulasim,
      ),
    ]);

    await tester.enterText(find.byType(TextField), 'igdas');
    await tester.pump();
    expect(find.text('İGDAŞ'), findsOneWidget);
    expect(find.text('Otobüs Kartı'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ulasim');
    await tester.pump();
    expect(find.text('Otobüs Kartı'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ulaşım');
    await tester.pump();
    expect(find.text('Otobüs Kartı'), findsOneWidget);
  });

  testWidgets('search includes a user-created category name', (tester) async {
    await _pumpTransactions(tester, [
      _transaction(merchant: 'Veteriner', categoryName: 'Evcil Hayvan'),
      _transaction(merchant: 'Market'),
    ]);

    await tester.enterText(find.byType(TextField), 'evcil hayvan');
    await tester.pump();
    expect(find.text('Veteriner'), findsOneWidget);
    expect(find.text('Market'), findsNothing);
  });

  testWidgets('empty state appears and clearing search restores all items', (
    tester,
  ) async {
    await _pumpTransactions(tester, [
      _transaction(merchant: 'İGDAŞ'),
      _transaction(merchant: 'Market'),
    ]);

    await tester.enterText(find.byType(TextField), 'bulunamaz');
    await tester.pump();
    expect(find.text('Aramanızla eşleşen işlem bulunamadı.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cancel_rounded));
    await tester.pump();
    expect(find.text('İGDAŞ'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
  });
}

Future<void> _pumpTransactions(
  WidgetTester tester,
  List<TransactionEntity> transactions,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TransactionsScreen(transactions: transactions)),
    ),
  );
  await tester.pump();
}

TransactionEntity _transaction({
  required String merchant,
  TransactionCategory category = TransactionCategory.market,
  String? categoryName,
}) {
  final now = DateTime(2026, 8, 4, 12);
  return TransactionEntity()
    ..amountInMinor = 10000
    ..category = category
    ..categoryName = categoryName
    ..date = now
    ..merchantName = merchant
    ..source = TransactionSource.manual
    ..createdAt = now
    ..updatedAt = now;
}
