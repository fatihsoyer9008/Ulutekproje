import 'dart:async';

import 'package:app_main/src/screens/expense_screen.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual entry shows institution category amount and date', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));
    await tester.tap(find.byKey(const Key('manual_entry_button')));
    await tester.pumpAndSettle();

    expect(find.text('Manuel Gider Ekle'), findsOneWidget);
    expect(find.text('MANUEL'), findsOneWidget);
    expect(find.byKey(const Key('institution_name_field')), findsOneWidget);
    expect(find.byKey(const Key('category_field')), findsOneWidget);
    expect(find.byKey(const Key('amount_field')), findsOneWidget);
    expect(find.byKey(const Key('date_field')), findsOneWidget);
    expect(find.text('TASLAK'), findsNothing);
  });

  testWidgets('manual entry rejects zero and invalid amounts', (tester) async {
    var saveCallCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(saveTransaction: (_) async => saveCallCount++),
      ),
    );

    await tester.tap(find.byKey(const Key('manual_entry_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('institution_name_field')),
      'Market',
    );
    await tester.enterText(find.byKey(const Key('category_field')), 'Market');
    await tester.enterText(find.byKey(const Key('amount_field')), '0');
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pump();

    expect(find.textContaining('sıfırdan büyük'), findsOneWidget);
    expect(saveCallCount, 0);

    await tester.enterText(find.byKey(const Key('amount_field')), 'geçersiz');
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pump();
    expect(find.textContaining('Geçerli bir tutar'), findsOneWidget);
    expect(saveCallCount, 0);
  });

  testWidgets('manual confirmation saves once and carries the selected date', (
    tester,
  ) async {
    final saveCompleter = Completer<void>();
    final savedTransactions = <TransactionEntity>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          saveTransaction: (transaction) {
            savedTransactions.add(transaction);
            return saveCompleter.future;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('manual_entry_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('institution_name_field')),
      'Market',
    );
    await tester.enterText(find.byKey(const Key('category_field')), 'Market');
    await tester.enterText(find.byKey(const Key('amount_field')), '100,00');
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pump();

    expect(savedTransactions, hasLength(1));
    expect(savedTransactions.single.amountInMinor, 10000);
    expect(savedTransactions.single.source, TransactionSource.manual);
    expect(savedTransactions.single.date.year, DateTime.now().year);
    expect(savedTransactions.single.date.month, DateTime.now().month);
    expect(savedTransactions.single.date.day, DateTime.now().day);

    saveCompleter.complete();
    await tester.pumpAndSettle();
    expect(savedTransactions, hasLength(1));
  });

  testWidgets('manual form remains usable with keyboard on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));
    await tester.tap(find.byKey(const Key('manual_entry_button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('amount_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('amount_field')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('confirm_draft_button')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('a new manual form is empty after a successful save', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open_expense_button'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ExpenseScreen(saveTransaction: (_) async {}),
                ),
              ),
              child: const Text('Gider aç'),
            ),
          ),
        ),
      ),
    );

    Future<void> openManualForm() async {
      await tester.tap(find.byKey(const Key('open_expense_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual_entry_button')));
      await tester.pumpAndSettle();
    }

    await openManualForm();
    await tester.enterText(
      find.byKey(const Key('institution_name_field')),
      'Market',
    );
    await tester.enterText(find.byKey(const Key('category_field')), 'Market');
    await tester.enterText(find.byKey(const Key('amount_field')), '10,00');
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();

    await openManualForm();
    for (final key in const [
      Key('institution_name_field'),
      Key('category_field'),
      Key('amount_field'),
    ]) {
      expect(
        tester.widget<TextFormField>(find.byKey(key)).controller?.text,
        isEmpty,
      );
    }
  });
}
