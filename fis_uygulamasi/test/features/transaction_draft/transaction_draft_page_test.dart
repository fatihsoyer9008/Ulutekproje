import 'package:app_main/features/transaction_draft/presentation/transaction_draft_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows editable UI and returns amountInMinor', (tester) async {
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
    expect(find.text('TASLAK'), findsOneWidget);
    expect(find.text('Fiş bilgilerini kontrol edin'), findsOneWidget);
    expect(find.text('İşlem bilgileri'), findsOneWidget);
    expect(find.byKey(const Key('institution_name_field')), findsOneWidget);
    expect(find.byKey(const Key('category_field')), findsOneWidget);
    expect(find.byKey(const Key('amount_field')), findsOneWidget);

    final amountField = tester.widget<TextFormField>(
      find.byKey(const Key('amount_field')),
    );
    expect(amountField.controller?.text, '1.234,56');
    expect(find.text('TL'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();
    expect(result?.amountInMinor, 123456);
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
                    initialDraft: const TransactionDraft(
                      institutionName: 'Kafe',
                      category: 'Yeme İçme',
                      amountInMinor: 2500,
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
}

CategoryEntity _category(String name) => CategoryEntity()
  ..name = name
  ..colorValue = 0xFF546E7A
  ..iconCodePoint = Icons.category_outlined.codePoint
  ..createdAt = DateTime(2026);
