import 'package:app_main/src/screens/calendar_screen.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('shows monthly totals and transactions for the selected day', (
    tester,
  ) async {
    final transactions = [
      _transaction(
        id: 1,
        date: DateTime(2026, 8, 15, 9, 30),
        amountInMinor: 300000,
        type: TransactionType.income,
        merchantName: 'Maaş',
      ),
      _transaction(
        id: 2,
        date: DateTime(2026, 8, 15, 18, 45),
        amountInMinor: 50000,
        merchantName: 'Market alışverişi',
      ),
      _transaction(
        id: 3,
        date: DateTime(2026, 8, 16, 12),
        amountInMinor: 20000,
        merchantName: 'Ulaşım',
      ),
      _transaction(
        id: 4,
        date: DateTime(2026, 7, 15),
        amountInMinor: 90000,
        merchantName: 'Önceki ay',
      ),
    ];

    await _pumpCalendar(tester, transactions: transactions);

    expect(find.byKey(const Key('calendar_monthly_income')), findsOneWidget);
    expect(find.text('₺3.000,00'), findsOneWidget);
    expect(find.text('₺700,00'), findsOneWidget);
    expect(find.text('+₺2.300,00'), findsOneWidget);
    expect(find.byKey(const Key('calendar_transaction_1')), findsOneWidget);
    expect(find.byKey(const Key('calendar_transaction_2')), findsOneWidget);
    expect(find.byKey(const Key('calendar_transaction_3')), findsNothing);
    expect(find.text('Maaş'), findsOneWidget);
    expect(find.text('Market alışverişi'), findsOneWidget);
  });

  testWidgets('selecting another day updates the transaction list', (
    tester,
  ) async {
    final transactions = [
      _transaction(
        id: 1,
        date: DateTime(2026, 8, 15, 9),
        amountInMinor: 10000,
        merchantName: '15 Ağustos işlemi',
      ),
      _transaction(
        id: 2,
        date: DateTime(2026, 8, 16, 10),
        amountInMinor: 20000,
        merchantName: '16 Ağustos işlemi',
      ),
    ];

    await _pumpCalendar(tester, transactions: transactions);
    expect(find.byKey(const Key('calendar_transaction_1')), findsOneWidget);

    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_transaction_1')), findsNothing);
    expect(find.byKey(const Key('calendar_transaction_2')), findsOneWidget);
    expect(find.text('16 Ağustos işlemi'), findsOneWidget);
  });

  testWidgets('shows an empty state when selected day has no transaction', (
    tester,
  ) async {
    await _pumpCalendar(tester, transactions: const []);

    expect(find.byKey(const Key('calendar_empty_day')), findsOneWidget);
    expect(
      find.text('Seçilen güne ait bir gelir veya gider yok.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required List<TransactionEntity> transactions,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CalendarScreen(
          transactions: transactions,
          initialFocusedDay: DateTime(2026, 8, 15),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TransactionEntity _transaction({
  required int id,
  required DateTime date,
  required int amountInMinor,
  TransactionType type = TransactionType.expense,
  String? merchantName,
}) => TransactionEntity()
  ..id = id
  ..transactionType = type
  ..amountInMinor = amountInMinor
  ..category = TransactionCategory.market
  ..date = date
  ..merchantName = merchantName
  ..source = TransactionSource.manual
  ..createdAt = date
  ..updatedAt = date;
