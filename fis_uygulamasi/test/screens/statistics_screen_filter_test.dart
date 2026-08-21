import 'package:app_main/src/screens/statistics_screen.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('period menu updates visible transaction categories', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 8, 15, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          referenceDate: now,
          transactions: [
            _transaction(date: DateTime(2026, 8, 15), categoryName: 'Bugün'),
            _transaction(date: DateTime(2026, 8, 2), categoryName: 'Bu Ay'),
            _transaction(date: DateTime(2026, 6, 1), categoryName: 'Üç Ay'),
            _transaction(date: DateTime(2026, 4, 1), categoryName: 'Altı Ay'),
            _transaction(date: DateTime(2025, 10, 1), categoryName: 'Bir Yıl'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Bu Ay'), findsOneWidget);
    expect(find.text('Üç Ay'), findsOneWidget);
    expect(find.text('Altı Ay'), findsOneWidget);
    expect(find.text('Bir Yıl'), findsNothing);

    await tester.tap(find.byKey(const Key('statistics_period_menu')));
    await tester.pumpAndSettle();
    expect(find.text('1 Ay'), findsWidgets);
    expect(find.text('3 Ay'), findsOneWidget);
    expect(find.text('6 Ay'), findsWidgets);
    expect(find.text('1 Yıl'), findsOneWidget);
    await tester.tap(find.text('3 Ay'));
    await tester.pumpAndSettle();

    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Bu Ay'), findsOneWidget);
    expect(find.text('Üç Ay'), findsOneWidget);
    expect(find.text('Altı Ay'), findsNothing);

    await tester.tap(find.byKey(const Key('statistics_period_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 Ay').last);
    await tester.pumpAndSettle();

    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Bu Ay'), findsOneWidget);
    expect(find.text('Üç Ay'), findsNothing);

    await tester.tap(find.byKey(const Key('statistics_period_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 Yıl'));
    await tester.pumpAndSettle();

    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Üç Ay'), findsOneWidget);
    expect(find.text('Altı Ay'), findsOneWidget);
    expect(find.text('Bir Yıl'), findsOneWidget);
  });

  testWidgets('smart summary is generated from current transaction data', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 15);
    final controller = StatisticsScreenController();
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          controller: controller,
          referenceDate: now,
          initialPeriod: StatisticsPeriod.oneMonth,
          transactions: [
            _transaction(date: now, amount: 7500, categoryName: 'Evcil Hayvan'),
            _transaction(date: now, amount: 2500, categoryName: 'Market'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showSummary();
    await tester.pumpAndSettle();

    expect(find.text('Akıllı Harcama Özeti'), findsOneWidget);
    expect(find.textContaining('Evcil Hayvan (%75)'), findsOneWidget);
    expect(find.textContaining('Geçen haftaya kıyasla'), findsNothing);
  });
}

TransactionEntity _transaction({
  required DateTime date,
  required String categoryName,
  int amount = 1000,
}) => TransactionEntity()
  ..amountInMinor = amount
  ..category = TransactionCategory.diger
  ..categoryName = categoryName
  ..date = date
  ..source = TransactionSource.manual
  ..transactionType = TransactionType.expense
  ..createdAt = date
  ..updatedAt = date;
