import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:app_main/features/transaction_draft/presentation/transaction_draft_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows TL value and returns amountInMinor', (tester) async {
    TransactionDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<TransactionDraft>(
                  MaterialPageRoute(
                    builder: (_) => const TransactionDraftPage(
                      initialDraft: TransactionDraft(
                        institutionName: 'Migros',
                        category: 'Market',
                        amountInMinor: 123456,
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

    final amountField = tester.widget<TextFormField>(
      find.byKey(const Key('amount_field')),
    );
    expect(amountField.controller?.text, '1.234,56');
    expect(find.text('TL'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();

    expect(result?.amountInMinor, 123456);
  });
}
