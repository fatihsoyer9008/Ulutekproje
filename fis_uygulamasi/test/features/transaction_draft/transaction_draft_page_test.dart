import 'package:app_main/features/transaction_draft/presentation/transaction_draft_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('ürünleri düzenler ve toplam uyuşmazlığı uyarısını günceller', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionDraftPage(
          initialDraft: TransactionDraft(
            institutionName: 'Migros',
            category: 'Market',
            amountInMinor: 3000,
            transactionDate: DateTime(2026, 8, 3),
            lineItems: const [
              ReceiptLineItemDraft(name: 'Süt', totalAmountInMinor: 1200),
              ReceiptLineItemDraft(name: 'Ekmek', totalAmountInMinor: 1300),
            ],
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('line_items_total_mismatch_warning')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(const Key('line_items_total_mismatch_warning')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('edit_line_item_Ekmek')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('line_item_total_field')),
      '18,00',
    );
    await tester.tap(find.byKey(const Key('save_line_item_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('line_items_total_mismatch_warning')),
      findsNothing,
    );
  });

  testWidgets('ürün kalemi ekler ve siler', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionDraftPage(
          initialDraft: TransactionDraft(
            institutionName: 'Migros',
            category: 'Market',
            amountInMinor: 1000,
            transactionDate: DateTime(2026, 8, 3),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('add_line_item_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('add_line_item_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('line_item_name_field')),
      'Yoğurt',
    );
    await tester.enterText(
      find.byKey(const Key('line_item_quantity_field')),
      '2',
    );
    await tester.enterText(
      find.byKey(const Key('line_item_total_field')),
      '10,00',
    );
    await tester.tap(find.byKey(const Key('save_line_item_button')));
    await tester.pumpAndSettle();

    expect(find.text('Yoğurt'), findsOneWidget);
    expect(find.text('2 adet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete_line_item_Yoğurt')));
    await tester.pump();
    expect(find.text('Yoğurt'), findsNothing);
  });
}

CategoryEntity _category(String name) => CategoryEntity()
  ..name = name
  ..colorValue = 0xFF546E7A
  ..iconCodePoint = Icons.category_outlined.codePoint
  ..createdAt = DateTime(2026);
