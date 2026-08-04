import 'package:app_main/features/transaction_draft/presentation/transaction_draft_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('güvenli analiz butonu', () {
    Future<void> pumpSubject(
      WidgetTester tester, {
      TransactionDraftPageMode mode = TransactionDraftPageMode.ocrReview,
      double? confidenceScore,
      bool isParseSuccessful = true,
      VoidCallback? onSecureAnalysisRequested,
    }) => tester.pumpWidget(
      MaterialApp(
        home: TransactionDraftPage(
          mode: mode,
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
        onSecureAnalysisRequested: () => requestCount++,
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

    expect(find.byKey(const Key('add_receipt_item_button')), findsNothing);
    expect(find.byKey(const Key('receipt_items_description')), findsNothing);
    expect(
      find.byKey(const Key('receipt_total_mismatch_warning')),
      findsNothing,
    );
    expect(find.text('Süt'), findsNothing);
    expect(find.text('Ekmek'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('confirm_draft_button')));
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();

    expect(result?.receiptItems.map((item) => item.name), ['Süt', 'Ekmek']);
    expect(result?.receiptItems.first.priceMinor, 2000);
    expect(result?.receiptItems.last.priceMinor, 1500);
  });
}

CategoryEntity _category(String name) => CategoryEntity()
  ..name = name
  ..colorValue = 0xFF546E7A
  ..iconCodePoint = Icons.category_outlined.codePoint
  ..createdAt = DateTime(2026);
