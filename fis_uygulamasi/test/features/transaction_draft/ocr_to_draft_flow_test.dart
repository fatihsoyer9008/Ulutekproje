import 'dart:async';

import 'package:app_main/core/database/database_providers.dart';
import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/src/screens/expense_screen.dart';
import 'package:finance_database/finance_database.dart'
    show
        CategoryEntity,
        ReceiptItem,
        TransactionDraft,
        TransactionEntity,
        TransactionSource;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows changing analysis messages while the API is pending', (
    tester,
  ) async {
    final response = Completer<ReceiptParseResult>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ExpenseScreen(
            scanReceipt: (_) async => 'OCR metni',
            parseReceipt: (_, {cancelToken}) => response.future,
          ),
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
        draft: TransactionDraft(
          institutionName: 'MIGROS',
          category: 'Market',
          amountInMinor: 2550,
        ),
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
                receiptItems: const [
                  ReceiptItem(
                    name: 'Süt 1L',
                    category: 'Gıda',
                    quantity: 1,
                    unitPriceInMinor: 2550,
                    totalAmountInMinor: 2550,
                  ),
                ],
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
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('category_field')),
          )
          .initialValue,
      'Market',
    );
    expect(find.widgetWithText(TextFormField, '25,50'), findsOneWidget);
    expect(find.byKey(const Key('transaction_date_field')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('receipt_items_summary_count')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 ürün kalemi bulundu.'), findsOneWidget);
    expect(find.byKey(const Key('secure_analysis_button')), findsNothing);
    expect(savedTransactions, isEmpty);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Düzeltilmiş OCR metni'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();
    expect(savedTransactions, hasLength(1));
    expect(savedTransactions.single.source, TransactionSource.ocrLlm);
  });

  testWidgets('does not open an empty review for an unreviewable parse', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'bozuk OCR',
          parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
            draft: TransactionDraft.empty(),
            normalizedOcrText: 'bozuk OCR',
            confidenceScore: 0.2,
            isParseSuccessful: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(find.text('İşlemi Kontrol Et'), findsNothing);
    expect(find.byKey(const Key('receipt_parse_error_dialog')), findsOneWidget);
    expect(
      find.textContaining(
        'Fişten kontrol edilebilir işlem bilgisi çıkarılamadı',
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps the scan flow locked until the current review opens', (
    tester,
  ) async {
    final categories = StreamController<List<CategoryEntity>>();
    addTearDown(categories.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => categories.stream),
        ],
        child: MaterialApp(
          home: ExpenseScreen(
            scanReceipt: (_) async => 'İLK FİŞ TOPLAM 25,50 TL',
            parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
              draft: TransactionDraft(
                institutionName: 'İLK MARKET',
                category: 'Market',
                amountInMinor: 2550,
              ),
              normalizedOcrText: 'İLK FİŞ TOPLAM 25,50 TL',
              confidenceScore: 0.9,
              isParseSuccessful: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final cameraButton = tester.widget<FilledButton>(
      find.byKey(const Key('ocr_camera_button')),
    );
    expect(cameraButton.onPressed, isNull);

    categories.add(const <CategoryEntity>[]);
    await tester.pumpAndSettle();

    expect(find.text('İşlemi Kontrol Et'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'İLK MARKET'), findsOneWidget);
  });

  testWidgets('a second scan shows only the newest receipt draft', (
    tester,
  ) async {
    var scanCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async {
            scanCount++;
            return scanCount == 1 ? 'İLK FİŞ' : 'İKİNCİ FİŞ';
          },
          parseReceipt: (text, {cancelToken}) async => ReceiptParseResult(
            draft: TransactionDraft(
              institutionName: text == 'İLK FİŞ' ? 'İLK MARKET' : 'YENİ MARKET',
              category: 'Market',
              amountInMinor: text == 'İLK FİŞ' ? 2550 : 4890,
            ),
            normalizedOcrText: text,
            confidenceScore: 0.9,
            isParseSuccessful: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'İLK MARKET'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'YENİ MARKET'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'İLK MARKET'), findsNothing);
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
