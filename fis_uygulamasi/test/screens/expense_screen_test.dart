import 'dart:async';

import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:app_main/src/screens/expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('renders the subscription empty state without dummy data', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(child: const MaterialApp(home: ExpenseScreen())),
    );

    expect(find.byKey(const Key('subscriptions_empty_state')), findsOneWidget);
    expect(find.text('Henüz kayıtlı aboneliğiniz yok'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
    expect(find.text('Kira'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Gideri Kaydet'), findsNothing);
    expect(find.text('Kamerayı Aç'), findsOneWidget);
    expect(find.text('Galeriden Yükle'), findsOneWidget);
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

  testWidgets('gallery action starts the gallery receipt flow', (tester) async {
    var galleryCallCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          pickGalleryReceipt: (_) async {
            galleryCallCount++;
            return null;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('gallery_upload_button')));
    await tester.pumpAndSettle();

    expect(galleryCallCount, 1);
    expect(find.byKey(const Key('expense_screen')), findsOneWidget);
  });

  testWidgets('gallery action shows analysis while local OCR is pending', (
    tester,
  ) async {
    final galleryResult = Completer<String?>();
    final parseResult = Completer<ReceiptParseResult>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ExpenseScreen(
            pickGalleryReceipt: (_) => galleryResult.future,
            parseReceipt: (_, {cancelToken}) => parseResult.future,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('gallery_upload_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('receipt_analysis_page')), findsOneWidget);

    galleryResult.complete('OCR');
    await tester.pump();
    expect(find.byKey(const Key('receipt_analysis_page')), findsOneWidget);

    parseResult.complete(
      const ReceiptParseResult(
        draft: TransactionDraft.empty(),
        normalizedOcrText: 'OCR',
        confidenceScore: 1,
        isParseSuccessful: true,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('gallery validation error shows a friendly message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          pickGalleryReceipt: (_) async =>
              throw const ReceiptImageValidationException(
                ReceiptImageValidationFailure.tooLarge,
                'Seçilen görsel 10 MB sınırını aşıyor. Lütfen daha küçük bir görsel seçin.',
              ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('gallery_upload_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('10 MB sınırını aşıyor'), findsOneWidget);
    expect(find.byKey(const Key('expense_screen')), findsOneWidget);
  });

  testWidgets('scanner cancellation preserves the expense empty state', (
    tester,
  ) async {
    var parseCallCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => null,
          parseReceipt: (_, {cancelToken}) async {
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
      find.byKey(const Key('gallery_upload_button')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manual_entry_button')).hitTestable(),
      findsOneWidget,
    );
  });
}
