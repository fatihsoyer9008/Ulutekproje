import 'dart:async';

import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:app_main/src/screens/expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  for (final testCase in <({ReceiptParserFailureKind kind, String message, bool canRetry})>[
    (
      kind: ReceiptParserFailureKind.rateLimited,
      message:
          'Çok fazla fiş analizi isteği gönderdiniz. Lütfen biraz bekleyip tekrar deneyin.',
      canRetry: false,
    ),
    (
      kind: ReceiptParserFailureKind.payloadTooLarge,
      message:
          'Fiş verisi işlenemeyecek kadar büyük. Lütfen fişi yeniden çekin veya bilgileri elle girin.',
      canRetry: false,
    ),
    (
      kind: ReceiptParserFailureKind.validation,
      message:
          'Fiş bilgileri doğrulanamadı. Lütfen fişi yeniden çekin veya bilgileri elle girin.',
      canRetry: false,
    ),
  ]) {
    testWidgets('${testCase.kind.name} mesajını hata diyaloğunda gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ExpenseScreen(
              scanReceipt: (_) async => 'OCR',
              parseReceipt: (_, {cancelToken}) async =>
                  throw ReceiptParserException(
                    testCase.message,
                    kind: testCase.kind,
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ocr_camera_button')));
      await tester.pumpAndSettle();

      expect(find.text(testCase.message), findsOneWidget);
      final retryButton = tester.widget<FilledButton>(
        find.byKey(const Key('retry_parse_button')),
      );
      expect(retryButton.onPressed, testCase.canRetry ? isNotNull : isNull);
    });
  }

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

  testWidgets('enables retry after the HTTP 429 Retry-After duration expires', (
    tester,
  ) async {
    var parseCallCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'MIGROS TOPLAM 25,50 TL',
          parseReceipt: (_, {cancelToken}) async {
            parseCallCount++;

            if (parseCallCount == 1) {
              throw const ReceiptParserException(
                'Fiş analiz kotanız doldu. 42 saniye sonra tekrar deneyebilirsiniz.',
                kind: ReceiptParserFailureKind.rateLimited,
                retryAfter: Duration(seconds: 42),
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

    FilledButton retryButton = tester.widget<FilledButton>(
      find.byKey(const Key('retry_parse_button')),
    );

    expect(retryButton.onPressed, isNull);
    expect(parseCallCount, 1);

    await tester.pump(const Duration(seconds: 41));

    retryButton = tester.widget<FilledButton>(
      find.byKey(const Key('retry_parse_button')),
    );
    expect(retryButton.onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));

    retryButton = tester.widget<FilledButton>(
      find.byKey(const Key('retry_parse_button')),
    );
    expect(retryButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('retry_parse_button')));
    await tester.pumpAndSettle();

    expect(parseCallCount, 2);
    expect(find.text('İşlemi Kontrol Et'), findsOneWidget);
  });

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
      expect(
        find.widgetWithText(FilledButton, 'Görseli güvenli analiz için gönder'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('secure_analysis_button')), findsOneWidget);
      expect(find.text('İşlemi Kontrol Et'), findsOneWidget);
    },
  );

  testWidgets('cancels the in-progress analysis and keeps expense entry open', (
    tester,
  ) async {
    final response = Completer<ReceiptParseResult>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('receipt_analysis_page')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('cancel_receipt_analysis_button')),
    );
    await tester.tap(find.byKey(const Key('cancel_receipt_analysis_button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('receipt_analysis_page')), findsNothing);
    expect(find.text('Gider Ekle'), findsOneWidget);
  });
}
