import 'package:app_main/src/models/ui_models.dart';
import 'package:app_main/src/screens/dashboard_screen.dart';
import 'package:app_main/src/screens/statistics/statistics_widgets.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('statistics chart clamps negative values to zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatisticsChart(
            spending: [
              MonthlySpending('Tem', -5000),
              MonthlySpending('Ağu', 2500),
            ],
          ),
        ),
      ),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final spots = chart.data.lineBarsData.single.spots;
    expect(spots.map((spot) => spot.y), [0, 25]);
    expect(chart.data.minY, 0);
  });

  testWidgets('dashboard actions use contrasting dark-theme colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: DashboardScreen(transactions: [])),
      ),
    );

    final scheme = AppTheme.dark.colorScheme;
    _expectButtonColors(tester, 'Gelir Gir', scheme.primary, scheme.onPrimary);
    _expectButtonColors(
      tester,
      'Gider Gir',
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
    );
  });
}

void _expectButtonColors(
  WidgetTester tester,
  String label,
  Color background,
  Color foreground,
) {
  final button = tester.widget<FilledButton>(
    find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
  );
  expect(button.style?.backgroundColor?.resolve({}), background);
  expect(button.style?.foregroundColor?.resolve({}), foreground);
  expect(_contrastRatio(background, foreground), greaterThanOrEqualTo(4.5));
}

double _contrastRatio(Color first, Color second) {
  final light = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final dark = identical(light, first) ? second : first;
  return (light.computeLuminance() + .05) / (dark.computeLuminance() + .05);
}
