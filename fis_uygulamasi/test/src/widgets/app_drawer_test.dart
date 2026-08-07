import 'package:app_main/core/theme/theme_mode_provider.dart';
import 'package:app_main/src/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('changes theme after drawer finishes closing', (tester) async {
    final container = ProviderContainer();
    final scaffoldKey = GlobalKey<ScaffoldState>();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: AppDrawer(onProfilePressed: () {}),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: Scaffold.of(context).openDrawer,
                child: const Text('Menü'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_theme_tile')));

    await tester.pump(const Duration(milliseconds: 250));
    expect(container.read(appThemeModeProvider), ThemeMode.light);

    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(appThemeModeProvider), ThemeMode.dark);
    expect(scaffoldKey.currentState?.isDrawerOpen, isFalse);
  });
}
