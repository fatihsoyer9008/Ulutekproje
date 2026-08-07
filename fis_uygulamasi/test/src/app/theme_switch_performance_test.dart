import 'package:app_main/src/app/finance_app.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('applies theme changes without an expensive transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      FinanceApp(
        transactionStream: Stream.value(const <TransactionEntity>[]),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationDuration, Duration.zero);
  });
}
