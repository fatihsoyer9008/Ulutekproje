import 'package:app_main/features/transaction_draft/presentation/transaction_draft_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';

void main() {
  group('güvenli analiz butonu', () {
    Future<void> pumpSubject(
      WidgetTester tester, {
      TransactionDraftPageMode mode = TransactionDraftPageMode.ocrReview,
      TransactionDraft? initialDraft,
      List<CategoryEntity>? categories,
      double? confidenceScore,
      bool isParseSuccessful = true,
      Future<ReceiptParseResult?> Function()? onSecureAnalysisRequested,
    }) => tester.pumpWidget(
      MaterialApp(
        home: TransactionDraftPage(
          mode: mode,
          initialDraft:
              initialDraft ??
              const TransactionDraft(
                institutionName: '',
                category: '',
                amountInMinor: 0,
              ),
          categories: categories ?? const <CategoryEntity>[],
          confidenceScore: confidenceScore,
          isParseSuccessful: isParseSuccessful,
          onSecureAnalysisRequested: onSecureAnalysisRequested,
        ),
      ),
    );
    testWidgets('yüzde 70 altındaki skorda gösterilir', (tester) async {
      await pumpSubject(tester, confidenceScore: .69);

      expect(find.byKey(const Key('secure_analysis_button')), findsOneWidget);
    });

    testWidgets('tam yüzde 70 skorda gösterilmez', (tester) async {
      await pumpSubject(tester, confidenceScore: .70);

      expect(find.byKey(const Key('secure_analysis_button')), findsNothing);
    });

    testWidgets('ayrıştırma başarısızsa yüksek skorda da gösterilir', (
      tester,
    ) async {
      await pumpSubject(tester, confidenceScore: .90, isParseSuccessful: false);

      expect(find.byKey(const Key('secure_analysis_button')), findsOneWidget);
    });

    testWidgets('güven skoru bulunmadığında gösterilmez', (tester) async {
      await pumpSubject(tester);

      expect(find.byKey(const Key('secure_analysis_button')), findsNothing);
    });

    testWidgets('manuel gider girişinde gösterilmez', (tester) async {
      await pumpSubject(
        tester,
        mode: TransactionDraftPageMode.manual,
        confidenceScore: .20,
      );

      expect(find.byKey(const Key('secure_analysis_button')), findsNothing);
    });

    testWidgets('gelir girişinde gösterilmez', (tester) async {
      await pumpSubject(
        tester,
        mode: TransactionDraftPageMode.income,
        confidenceScore: .20,
      );

      expect(find.byKey(const Key('secure_analysis_button')), findsNothing);
    });

    testWidgets('callback verildiğinde aktiftir ve bir kez çağrılır', (
      tester,
    ) async {
      var requestCount = 0;
      await pumpSubject(
        tester,
        confidenceScore: .20,
        onSecureAnalysisRequested: () async {
          requestCount++;
          return null;
        },
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('secure_analysis_button')),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('secure_analysis_button')));
      await tester.pump();

      expect(requestCount, 1);
      expect(
        find.byKey(const Key('secure_analysis_coming_soon')),
        findsNothing,
      );
    });

    testWidgets('callback yoksa pasiftir ve yakında açıklaması gösterilir', (
      tester,
    ) async {
      await pumpSubject(tester, confidenceScore: .20);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('secure_analysis_button')),
      );
      expect(button.onPressed, isNull);
      expect(
        find.text('Güvenli analiz özelliği yakında kullanıma açılacak.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('secure_analysis_coming_soon')),
        findsOneWidget,
      );
    });

    testWidgets('güvenli analiz kullanıcının dolu alanlarını ezmez', (
      tester,
    ) async {
      final userDate = DateTime(2026, 8, 6);

      await pumpSubject(
        tester,
        confidenceScore: .20,
        initialDraft: TransactionDraft(
          institutionName: 'Elle Girilen Market',
          category: 'Market',
          amountInMinor: 1234,
          transactionDate: userDate,
          receiptItems: const [
            ReceiptItem(name: 'Elle Eklenen Ürün', priceMinor: 1234),
          ],
        ),
        categories: [_category('Market'), _category('Yeme İçme')],
        onSecureAnalysisRequested: () async {
          return ReceiptParseResult(
            draft: TransactionDraft(
              institutionName: 'Sunucudan Gelen Kurum',
              category: 'Yeme İçme',
              amountInMinor: 2550,
              transactionDate: DateTime(2026, 8, 1),
              receiptItems: const [
                ReceiptItem(name: 'Sunucudan Gelen Ürün', priceMinor: 2550),
              ],
            ),
            normalizedOcrText: 'SUNUCU OCR METNİ',
            confidenceScore: .95,
            isParseSuccessful: true,
          );
        },
      );

      await tester.tap(find.byKey(const Key('secure_analysis_button')));
      await tester.pumpAndSettle();

      final institutionField = tester.widget<TextFormField>(
        find.byKey(const Key('institution_name_field')),
      );
      final amountField = tester.widget<TextFormField>(
        find.byKey(const Key('amount_field')),
      );
      final dateField = tester.widget<TextFormField>(
        find.byKey(const Key('transaction_date_field')),
      );

      expect(institutionField.controller?.text, 'Elle Girilen Market');
      expect(amountField.controller?.text, '12,34');
      expect(dateField.controller?.text, '06.08.2026');
      expect(find.text('Market'), findsWidgets);

      await tester.scrollUntilVisible(
        find.byKey(const Key('view_receipt_items_button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final viewItemsButton = tester.widget<TextButton>(
        find.byKey(const Key('view_receipt_items_button')),
      );
      viewItemsButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('Elle Eklenen Ürün'), findsOneWidget);
      expect(find.text('Sunucudan Gelen Ürün'), findsNothing);
    });
  });

  testWidgets(
    'OCR tarihi ve metni onay ekranında korunur, kullanıcı tarihi değiştirir',
    (tester) async {
      TransactionDraft? result;
      final receiptDate = DateTime(2026, 7, 30);
      final selectedDate = DateTime(2026, 7, 15);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<TransactionDraft>(
                    MaterialPageRoute(
                      builder: (_) => TransactionDraftPage(
                        mode: TransactionDraftPageMode.ocrReview,
                        initialDraft: TransactionDraft(
                          institutionName: 'Migros',
                          category: 'Market',
                          amountInMinor: 123456,
                          transactionDate: receiptDate,
                          rawOcrText: 'MIGROS\nTOPLAM 1.234,56 TL',
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      final dateField = tester.widget<TextFormField>(
        find.byKey(const Key('transaction_date_field')),
      );
      expect(dateField.controller?.text, '30.07.2026');

      await tester.tap(find.byKey(const Key('transaction_date_field')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      final dialogContext = tester.element(find.byType(DatePickerDialog));
      Navigator.of(dialogContext).pop(selectedDate);
      await tester.pumpAndSettle();

      final updatedDateField = tester.widget<TextFormField>(
        find.byKey(const Key('transaction_date_field')),
      );
      expect(updatedDateField.controller?.text, '15.07.2026');

      await tester.tap(find.byKey(const Key('confirm_draft_button')));
      await tester.pumpAndSettle();

      expect(result?.amountInMinor, 123456);
      expect(result?.transactionDate, selectedDate);
      expect(result?.rawOcrText, 'MIGROS\nTOPLAM 1.234,56 TL');
    },
  );

  testWidgets(
    'Backend tarih göndermediğinde tarih alanı boş açılır ve kullanıcı tarih seçebilir',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TransactionDraftPage(
            initialDraft: TransactionDraft(
              institutionName: 'Migros',
              category: 'Market',
              amountInMinor: 2550,
              rawOcrText: 'MIGROS\nTOPLAM 25,50 TL',
            ),
          ),
        ),
      );

      final dateField = tester.widget<TextFormField>(
        find.byKey(const Key('transaction_date_field')),
      );

      expect(dateField.controller?.text, '');
      expect(
        find.text('Tarih bulunamadı - seçmek için dokunun'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('transaction_date_field')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      final dialogContext = tester.element(find.byType(DatePickerDialog));
      Navigator.of(dialogContext).pop(DateTime(2026, 7, 20));
      await tester.pumpAndSettle();

      final updatedDateField = tester.widget<TextFormField>(
        find.byKey(const Key('transaction_date_field')),
      );
      expect(updatedDateField.controller?.text, '20.07.2026');
    },
  );

  testWidgets('OCR modunda tarih seçilmeden onay verilemez', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TransactionDraftPage(
          initialDraft: TransactionDraft(
            institutionName: 'Migros',
            category: 'Market',
            amountInMinor: 2550,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pump();

    expect(find.text('Fiş tarihi zorunludur'), findsOneWidget);
    expect(find.byKey(const Key('transaction_date_field')), findsOneWidget);
  });

  testWidgets('OCR kategorisini listede olmasa da seçili tutar', (
    tester,
  ) async {
    TransactionDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<TransactionDraft>(
                MaterialPageRoute(
                  builder: (_) => TransactionDraftPage(
                    initialDraft: TransactionDraft(
                      institutionName: 'Kafe',
                      category: 'Yeme İçme',
                      amountInMinor: 2500,
                      transactionDate: DateTime(2026, 7, 31),
                    ),
                    categories: [_category('Market')],
                  ),
                ),
              );
            },
            child: const Text('Aç'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Yeme İçme'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();
    expect(result?.category, 'Yeme İçme');
  });

  testWidgets('veritabanından gelen özel kategoriyi dropdown içinde gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionDraftPage(
          initialDraft: const TransactionDraft(
            institutionName: 'Veteriner',
            category: 'Evcil Hayvan',
            amountInMinor: 5000,
          ),
          categories: [_category('Market'), _category('Evcil Hayvan')],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('category_field')));
    await tester.pumpAndSettle();
    expect(find.text('Evcil Hayvan'), findsWidgets);
  });

  testWidgets('fiş ürünlerini ekranda göstermeden taslakta korur', (
    tester,
  ) async {
    TransactionDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<TransactionDraft>(
                MaterialPageRoute(
                  builder: (_) => TransactionDraftPage(
                    initialDraft: TransactionDraft(
                      institutionName: 'Migros',
                      category: 'Market',
                      amountInMinor: 3500,
                      transactionDate: DateTime(2026, 8, 3),
                      receiptItems: const [
                        ReceiptItem(name: 'Süt', priceMinor: 2000),
                        ReceiptItem(name: 'Ekmek', priceMinor: 1500),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: const Text('Aç'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('receipt_items_summary_count')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('receipt_items_summary_count')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('view_receipt_items_button')), findsOneWidget);
    expect(find.text('Süt'), findsNothing);
    expect(find.text('Ekmek'), findsNothing);
    await tester.tap(find.byKey(const Key('view_receipt_items_button')));
    await tester.pumpAndSettle();

    expect(find.text('Süt'), findsOneWidget);
    expect(find.text('Ekmek'), findsOneWidget);
    await tester.tap(find.byKey(const Key('apply_receipt_items_button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('confirm_draft_button')));
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();

    expect(result?.receiptItems.map((item) => item.name), ['Süt', 'Ekmek']);
    expect(result?.receiptItems.first.priceMinor, 2000);
    expect(result?.receiptItems.last.priceMinor, 1500);
  });

  testWidgets('onaylanan ürün toplamını ana taslağa açıkça uygular', (
    tester,
  ) async {
    TransactionDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<TransactionDraft>(
                MaterialPageRoute(
                  builder: (_) => TransactionDraftPage(
                    mode: TransactionDraftPageMode.ocrReview,
                    initialDraft: TransactionDraft(
                      institutionName: 'Market',
                      category: 'Market',
                      amountInMinor: 2500,
                      transactionDate: DateTime(2026, 8, 4),
                      receiptItems: const [
                        ReceiptItem(name: 'Kahve', totalAmountInMinor: 3000),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('view_receipt_items_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('view_receipt_items_button')));
    await tester.pumpAndSettle();

    expect(find.text('Kahve'), findsOneWidget);
    await tester.tap(find.byKey(const Key('use_receipt_items_total_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_use_items_total_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply_receipt_items_button')));
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextFormField>(
      find.byKey(const Key('amount_field')),
    );
    expect(amountField.controller?.text, '30,00');
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();
    expect(result?.amountInMinor, 3000);
    expect(result?.receiptItems.single.name, 'Kahve');
  });
}

CategoryEntity _category(String name) => CategoryEntity()
  ..name = name
  ..colorValue = 0xFF546E7A
  ..iconCodePoint = Icons.category_outlined.codePoint
  ..createdAt = DateTime(2026);
