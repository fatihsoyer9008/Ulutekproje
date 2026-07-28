import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:app_main/features/transaction_draft/presentation/transaction_draft_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('draft screen shows editable receipt information', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TransactionDraftPage(
          initialDraft: TransactionDraft(
            institutionName: 'Migros',
            category: 'Market',
            amount: 1234.56,
          ),
        ),
      ),
    );

    expect(find.text('TASLAK'), findsOneWidget);
    expect(find.text('Fiş bilgilerini kontrol edin'), findsOneWidget);
    expect(find.text('İşlem bilgileri'), findsOneWidget);
    expect(find.byKey(const Key('institution_name_field')), findsOneWidget);
    expect(find.byKey(const Key('category_field')), findsOneWidget);
    expect(find.byKey(const Key('amount_field')), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    expect(find.text('Onayla'), findsOneWidget);

    final amountField = tester.widget<TextFormField>(
      find.byKey(const Key('amount_field')),
    );
    expect(amountField.controller?.text, '1234,56');
  });
}
