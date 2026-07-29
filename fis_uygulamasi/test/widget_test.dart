import 'dart:async';

import 'package:app_main/main.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('dashboard and navigation render', (tester) async {
    final first = _transaction(
      amountInMinor: 250000,
      transactionType: TransactionType.income,
      merchantName: 'Maaş',
    );
    final second = _transaction(amountInMinor: 50000);
    await tester.pumpWidget(
      FinanceApp(transactionStream: Stream.value([first, second])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kontrol sende.'), findsOneWidget);
    expect(find.text('₺2.000,00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Genel İstatistik'), findsOneWidget);
  });

  testWidgets('expense screen exposes OCR action', (tester) async {
    await tester.pumpWidget(const FinanceApp());
    await tester.tap(find.text('Gider Gir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ocr_camera_button')), findsOneWidget);
    expect(find.text('Abonelikler'), findsOneWidget);
  });

  testWidgets('balance updates when transaction stream emits new data', (
    tester,
  ) async {
    final transactions = StreamController<List<TransactionEntity>>();
    addTearDown(transactions.close);
    final first = _transaction(amountInMinor: 10000);
    final second = _transaction(
      amountInMinor: 2500,
      transactionType: TransactionType.income,
      merchantName: 'Ek gelir',
    );

    await tester.pumpWidget(FinanceApp(transactionStream: transactions.stream));

    transactions.add([first]);
    await tester.pumpAndSettle();
    expect(find.text('-₺100,00'), findsOneWidget);

    transactions.add([first, second]);
    await tester.pumpAndSettle();
    expect(find.text('-₺75,00'), findsOneWidget);
    expect(find.text('-₺100,00'), findsNothing);
  });

  testWidgets('saving a manual expense updates the dashboard balance', (
    tester,
  ) async {
    final transactions = StreamController<List<TransactionEntity>>();
    addTearDown(transactions.close);
    final savedTransactions = <TransactionEntity>[];

    await tester.pumpWidget(
      FinanceApp(
        transactionStream: transactions.stream,
        saveTransaction: (transaction) async {
          savedTransactions.add(transaction);
          transactions.add(List.of(savedTransactions));
        },
      ),
    );
    transactions.add([]);
    await tester.pump();

    await tester.tap(find.text('Gider Gir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual_entry_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('institution_name_field')),
      'Market',
    );
    await tester.enterText(find.byKey(const Key('category_field')), 'Market');
    await tester.enterText(find.byKey(const Key('amount_field')), '100,00');
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();

    expect(savedTransactions, hasLength(1));
    expect(savedTransactions.single.amountInMinor, 10000);
    expect(savedTransactions.single.source, TransactionSource.manual);
    expect(savedTransactions.single.transactionType, TransactionType.expense);
    expect(find.byKey(const Key('total_balance')), findsOneWidget);
    expect(find.text('-₺100,00'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('-₺100,00'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.insights_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('₺100,00'), findsOneWidget);
  });

  testWidgets('saving income increases balance and appears in movements', (
    tester,
  ) async {
    final transactions = StreamController<List<TransactionEntity>>();
    addTearDown(transactions.close);
    final savedTransactions = <TransactionEntity>[];

    await tester.pumpWidget(
      FinanceApp(
        transactionStream: transactions.stream,
        saveTransaction: (transaction) async {
          savedTransactions.add(transaction);
          transactions.add(List.of(savedTransactions));
        },
      ),
    );
    transactions.add([]);
    await tester.pump();

    await tester.tap(find.text('Gelir Gir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_income_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('institution_name_field')),
      'Maaş',
    );
    await tester.enterText(find.byKey(const Key('category_field')), 'Maaş');
    await tester.enterText(find.byKey(const Key('amount_field')), '1.000,00');
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();

    expect(savedTransactions, hasLength(1));
    expect(savedTransactions.single.amountInMinor, 100000);
    expect(savedTransactions.single.transactionType, TransactionType.income);
    expect(find.text('₺1.000,00'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Maaş'), findsOneWidget);
    expect(find.text('+₺1.000,00'), findsOneWidget);
  });
}

TransactionEntity _transaction({
  required int amountInMinor,
  TransactionType transactionType = TransactionType.expense,
  TransactionCategory category = TransactionCategory.market,
  String merchantName = 'Market',
  DateTime? date,
}) {
  final effectiveDate = date ?? DateTime.now();
  return TransactionEntity()
    ..transactionType = transactionType
    ..amountInMinor = amountInMinor
    ..category = category
    ..date = effectiveDate
    ..merchantName = merchantName
    ..source = TransactionSource.manual
    ..createdAt = effectiveDate
    ..updatedAt = effectiveDate;
}
