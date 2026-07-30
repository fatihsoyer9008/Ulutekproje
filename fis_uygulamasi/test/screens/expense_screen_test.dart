import 'dart:async';

import 'package:app_main/src/screens/expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

void main() {
  testWidgets('renders the subscription empty state without dummy data', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));

    expect(find.byKey(const Key('subscriptions_empty_state')), findsOneWidget);
    expect(find.text('Henüz kayıtlı aboneliğiniz yok'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
    expect(find.text('Kira'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Gideri Kaydet'), findsNothing);
    expect(find.text('Fişi Tara'), findsOneWidget);
    expect(find.text('Fişim yok, elle gireceğim'), findsOneWidget);
  });

  testWidgets('camera action opens ReceiptScannerScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ReceiptScannerScreen), findsOneWidget);
  });

  testWidgets('repeated camera taps start only one scanner flow', (
    tester,
  ) async {
    var scanCallCount = 0;
    final scanCompleter = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) {
            scanCallCount++;
            return scanCompleter.future;
          },
        ),
      ),
    );

    final cameraButton = find.byKey(const Key('ocr_camera_button'));
    await tester.tap(cameraButton);
    await tester.tap(cameraButton);
    expect(scanCallCount, 1);

    scanCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('scanner cancellation preserves the expense empty state', (
    tester,
  ) async {
    var parseCallCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => null,
          parseReceipt: (_) async {
            parseCallCount++;
            throw StateError('should not parse a cancelled scan');
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(parseCallCount, 0);
    expect(find.byKey(const Key('expense_screen')), findsOneWidget);
    expect(find.byKey(const Key('subscriptions_empty_state')), findsOneWidget);
  });

  testWidgets('expense actions do not overflow on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('ocr_camera_button')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manual_entry_button')).hitTestable(),
      findsOneWidget,
    );
  });
}
