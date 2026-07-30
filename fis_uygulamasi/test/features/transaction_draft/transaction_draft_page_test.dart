import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:app_main/features/transaction_draft/presentation/transaction_draft_page.dart';
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
}