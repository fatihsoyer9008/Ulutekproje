import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme reuses its prebuilt themes', () {
    expect(identical(AppTheme.light, AppTheme.light), isTrue);
    expect(identical(AppTheme.dark, AppTheme.dark), isTrue);
  });

  test('light and dark themes keep identical text metrics', () {
    final light = AppTheme.light.textTheme;
    final dark = AppTheme.dark.textTheme;

    for (final styles in [
      (light.headlineLarge, dark.headlineLarge),
      (light.headlineMedium, dark.headlineMedium),
      (light.titleLarge, dark.titleLarge),
      (light.titleMedium, dark.titleMedium),
      (light.bodyLarge, dark.bodyLarge),
      (light.bodyMedium, dark.bodyMedium),
    ]) {
      expect(styles.$1?.fontSize, styles.$2?.fontSize);
      expect(styles.$1?.fontWeight, styles.$2?.fontWeight);
      expect(styles.$1?.letterSpacing, styles.$2?.letterSpacing);
      expect(styles.$1?.height, styles.$2?.height);
    }
  });

  testWidgets('AppCard renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppCard(child: Text('İçerik'))),
      ),
    );

    expect(find.text('İçerik'), findsOneWidget);
  });
}
