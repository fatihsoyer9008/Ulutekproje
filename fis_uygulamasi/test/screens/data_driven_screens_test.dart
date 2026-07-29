import 'package:app_main/src/models/ui_models.dart';
import 'package:app_main/src/screens/savings_screen.dart';
import 'package:app_main/src/screens/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('savings screen explains that no goals exist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SavingsScreen())),
    );

    expect(find.text('Henüz birikim hedefi bulunmuyor.'), findsOneWidget);
  });

  testWidgets('statistics accepts monthly amounts in minor units', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatisticsScreen(
            monthlySpending: [MonthlySpending('Tem', 123456)],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tem'), findsOneWidget);
    expect(find.text('Henüz harcama verisi bulunmuyor.'), findsNothing);
  });
}
