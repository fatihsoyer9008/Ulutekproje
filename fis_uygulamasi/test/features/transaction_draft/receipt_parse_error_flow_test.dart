import 'dart:async';

import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:app_main/src/screens/expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('retries the same OCR text from the user-safe error dialog', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'MIGROS TOPLAM 25,50 TL',
          parseReceipt: (_, {cancelToken}) async {
            callCount++;
            if (callCount == 1) {
              throw const ReceiptParserException(
                'Fiş analizi beklenenden uzun sürdü.',
                kind: ReceiptParserFailureKind.timeout,
              );
            }
            return const ReceiptParseResult(
              draft: TransactionDraft(
                institutionName: 'MIGROS',
                category: 'Market',
                amountInMinor: 2550,
              ),
              normalizedOcrText: 'MIGROS TOPLAM 25,50 TL',
              confidenceScore: 0.9,
              isParseSuccessful: true,
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receipt_parse_error_dialog')), findsOneWidget);
    expect(find.text('Fiş analizi beklenenden uzun sürdü.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry_parse_button')));
    await tester.pumpAndSettle();

    expect(callCount, 2);
    expect(find.text('İşlemi Kontrol Et'), findsOneWidget);
    expect(find.text('Fiş analizi beklenenden uzun sürdü.'), findsNothing);
  });

  testWidgets(
    'shows the quota message and disables immediate retry for HTTP 429',
    (tester) async {
      var parseCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseScreen(
            scanReceipt: (_) async => 'MIGROS TOPLAM 25,50 TL',
            parseReceipt: (_, {cancelToken}) async {
              parseCallCount++;
              throw const ReceiptParserException(
                'Fiş analiz kotanız doldu. 42 saniye sonra tekrar deneyebilirsiniz.',
                kind: ReceiptParserFailureKind.rateLimited,
                retryAfter: Duration(seconds: 42),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ocr_camera_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('receipt_parse_error_dialog')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Fiş analiz kotanız doldu. 42 saniye sonra tekrar deneyebilirsiniz.',
        ),
        findsOneWidget,
      );

      final retryButton = tester.widget<FilledButton>(
        find.byKey(const Key('retry_parse_button')),
      );

      expect(retryButton.onPressed, isNull);
      expect(parseCallCount, 1);
    },
  );

  testWidgets('opens manual entry from the parse error dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'OCR',
          parseReceipt: (_, {cancelToken}) async =>
              throw const ReceiptParserException(
                'İnternet bağlantısı bulunamadı.',
                kind: ReceiptParserFailureKind.noInternet,
              ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('manual_entry_after_parse_error_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manuel Gider Ekle'), findsOneWidget);
    expect(find.byKey(const Key('receipt_parse_error_dialog')), findsNothing);
  });

  testWidgets(
    'shows a retake suggestion for a low-confidence fallback result',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseScreen(
            scanReceipt: (_) async => 'MIGROS TOPLAM 25,50 TL',
            parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
              draft: TransactionDraft(
                institutionName: 'MIGROS',
                category: 'Diğer',
                amountInMinor: 2550,
              ),
              normalizedOcrText: 'MIGROS TOPLAM 25,50 TL',
              confidenceScore: .35,
              isParseSuccessful: false,
              usedLocalFallback: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ocr_camera_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('retake_receipt_suggestion')),
        findsOneWidget,
      );
      expect(find.text('İşlemi Kontrol Et'), findsOneWidget);
    },
  );

  testWidgets('cancels the in-progress analysis and keeps expense entry open', (
    tester,
  ) async {
    final response = Completer<ReceiptParseResult>();
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'OCR',
          parseReceipt: (_, {cancelToken}) {
            cancelToken!.whenCancel.then((_) {
              response.completeError(
                const ReceiptParserException(
                  'Fiş analizi iptal edildi.',
                  kind: ReceiptParserFailureKind.cancelled,
                ),
              );
            });
            return response.future;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('receipt_analysis_page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel_receipt_analysis_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receipt_analysis_page')), findsNothing);
    expect(find.text('Gider Ekle'), findsOneWidget);
  });
}
