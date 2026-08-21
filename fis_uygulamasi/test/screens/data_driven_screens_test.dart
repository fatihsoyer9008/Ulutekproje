import 'package:app_main/src/models/ui_models.dart';
import 'package:app_main/src/screens/savings_screen.dart';
import 'package:app_main/src/screens/statistics_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('savings screen explains that no goals exist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SavingsScreen())),
    );

    expect(find.text('Birikim Hedeflerinizi Belirleyin'), findsOneWidget);
  });

  testWidgets('savings empty state uses dark theme surfaces and text colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: SavingsScreen()),
      ),
    );

    final context = tester.element(find.byType(SavingsScreen));
    final scheme = Theme.of(context).colorScheme;
    final description = tester.widget<Text>(
      find.byKey(const Key('savings_empty_description')),
    );
    final illustration = tester.widget<DecoratedBox>(
      find.byKey(const Key('savings_onboarding_illustration')),
    );
    final previewCard = tester.widget<Container>(
      find.byKey(
        const ValueKey('savings_onboarding_goal_Haftalık Tatil\nFonu'),
      ),
    );

    expect(description.style?.color, scheme.onSurfaceVariant);
    expect(
      (illustration.decoration as BoxDecoration).color,
      scheme.surfaceContainerLow,
    );
    expect(
      (previewCard.decoration as BoxDecoration).color,
      scheme.surfaceContainerHighest,
    );
  });

  testWidgets('savings goals use featured and vertical list layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SavingsScreen(
            goals: [
              SavingGoal(
                'Yeni Araba',
                4200,
                12000,
                Icons.directions_car_rounded,
                Colors.pink,
              ),
              SavingGoal(
                'Tatil',
                6500,
                10000,
                Icons.flight_takeoff_rounded,
                Colors.teal,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PageView), findsNothing);
    expect(find.byKey(const Key('savings_vertical_list')), findsOneWidget);
    expect(find.text('🎯'), findsOneWidget);
    expect(find.text('Ana Hedef'), findsOneWidget);
    expect(find.text('Diğer Birikimlerim'), findsOneWidget);
    expect(find.textContaining('Kalan:'), findsNWidgets(2));
    expect(find.text('%65'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('savings_vertical_list')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('savings_bottom_safe_space')), findsOneWidget);
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
