import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme reuses its prebuilt themes', () {
    expect(identical(AppTheme.light, AppTheme.light), isTrue);
    expect(identical(AppTheme.dark, AppTheme.dark), isTrue);
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
