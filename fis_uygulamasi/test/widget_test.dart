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
    final first = TransactionEntity()..amountInMinor = 123456;
    final second = TransactionEntity()..amountInMinor = 76544;
    await tester.pumpWidget(
      FinanceApp(transactionLoader: () async => [first, second]),
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
}
