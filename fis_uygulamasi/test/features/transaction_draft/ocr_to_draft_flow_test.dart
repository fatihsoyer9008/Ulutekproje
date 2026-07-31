import 'dart:async';

import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/src/screens/expense_screen.dart';
import 'package:finance_database/finance_database.dart'
    show TransactionDraft, TransactionEntity, TransactionSource;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows changing analysis messages while the API is pending', (
    tester,
  ) async {
    final response = Completer<ReceiptParseResult>();
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'OCR metni',
          parseReceipt: (_, {cancelToken}) => response.future,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('receipt_analysis_page')), findsOneWidget);
    expect(find.text('Gider Ekle'), findsNothing);
    expect(find.text('Fişiniz inceleniyor...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2900));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Rakamlar tek tek doğrulanıyor...'), findsOneWidget);

    response.complete(
      const ReceiptParseResult(
        draft: TransactionDraft.empty(),
        normalizedOcrText: 'OCR metni',
        confidenceScore: 0.9,
        isParseSuccessful: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receipt_analysis_page')), findsNothing);
    expect(find.text('İşlemi Kontrol Et'), findsOneWidget);
  });

  testWidgets('opens the populated confirmation page after OCR parsing', (
    tester,
  ) async {
    String? parsedText;
    final savedTransactions = <TransactionEntity>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'MİGROS TOPLAM 25,50 TL',
          parseReceipt: (text, {cancelToken}) async {
            parsedText = text;
            return ReceiptParseResult(
              draft: TransactionDraft(
                institutionName: 'MİGROS',
                category: 'Market',
                amountInMinor: 2550,
                transactionDate: DateTime(2026, 7, 28),
              ),
              normalizedOcrText: 'MİGROS\nTOPLAM 25,50 TL',
              confidenceScore: 0.92,
              isParseSuccessful: true,
            );
          },
          saveTransaction: (transaction) async {
            savedTransactions.add(transaction);
          },
        ),
      ),
    );

    expect(find.byKey(const Key('manual_entry_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(parsedText, 'MİGROS TOPLAM 25,50 TL');
    expect(find.text('İşlemi Kontrol Et'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'MİGROS'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Market'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '25,50'), findsOneWidget);
    expect(find.byKey(const Key('transaction_date_field')), findsOneWidget);
    expect(savedTransactions, isEmpty);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Düzeltilmiş OCR metni'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();
    expect(savedTransactions, hasLength(1));
    expect(savedTransactions.single.source, TransactionSource.ocrLlm);
  });

  testWidgets('shows the confidence warning for an unsuccessful parse', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'bozuk OCR',
          parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
            draft: TransactionDraft.empty(),
            normalizedOcrText: 'bozuk OCR',
            confidenceScore: 0.85,
            isParseSuccessful: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Tutar veya kurum adından tam emin olamadık, lütfen kontrol edin',
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps the expense screen open when parsing fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'OCR',
          parseReceipt: (_, {cancelToken}) async =>
              throw const ReceiptParserException('Sunucuya ulaşılamadı'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(find.text('Gider Ekle'), findsOneWidget);
    expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
    expect(find.byKey(const Key('subscriptions_empty_state')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('ocr_camera_button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('OCR kaydı fiş tarihi, ham metin ve OCR kaynağıyla kaydedilir', (
    tester,
  ) async {
    const rawOcrText = 'MIGROS TOPLAM 25.50 TL';
    const normalizedOcrText = 'MIGROS\nTOPLAM 25,50 TL';

    TransactionEntity? savedTransaction;
    final receiptDate = DateTime(2026, 7, 28, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open_expense_screen'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExpenseScreen(
                      scanReceipt: (_) async => rawOcrText,
                      parseReceipt: (_, {cancelToken}) async =>
                          ReceiptParseResult(
                            draft: TransactionDraft(
                              institutionName: 'MIGROS',
                              category: 'Market',
                              amountInMinor: 2550,
                              transactionDate: receiptDate,
                            ),
                            normalizedOcrText: normalizedOcrText,
                            confidenceScore: 0.92,
                            isParseSuccessful: true,
                          ),
                      saveTransaction: (transaction) async {
                        savedTransaction = transaction;
                      },
                    ),
                  ),
                );
              },
              child: const Text('Gider ekranını aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_expense_screen')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();

    expect(savedTransaction, isNotNull);
    expect(savedTransaction!.source, TransactionSource.ocrLlm);
    expect(savedTransaction!.rawOcrText, rawOcrText);
    expect(savedTransaction!.rawOcrText, isNot(normalizedOcrText));
    expect(savedTransaction!.date, receiptDate);
    expect(savedTransaction!.amountInMinor, 2550);
  });
}
