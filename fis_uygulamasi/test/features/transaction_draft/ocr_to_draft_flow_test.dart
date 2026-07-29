import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:app_main/src/screens/expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the populated confirmation page after OCR parsing', (
    tester,
  ) async {
    String? parsedText;
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'MİGROS TOPLAM 25,50 TL',
          parseReceipt: (text) async {
            parsedText = text;
            return const ReceiptParseResult(
              draft: TransactionDraft(
                institutionName: 'MİGROS',
                category: 'Market',
                amountInMinor: 2550,
              ),
              normalizedOcrText: 'MİGROS\nTOPLAM 25,50 TL',
              confidenceScore: 0.92,
              isParseSuccessful: true,
            );
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
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Düzeltilmiş OCR metni'), findsOneWidget);
  });

  testWidgets('manual entry uses manual copy instead of AI draft copy', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));

    await tester.tap(find.byKey(const Key('manual_entry_button')));
    await tester.pumpAndSettle();

    expect(find.text('Manuel Gider Ekle'), findsOneWidget);
    expect(find.text('MANUEL'), findsOneWidget);
    expect(find.text('Gider bilgilerini girin'), findsOneWidget);
    expect(find.textContaining('yapay zekânın çıkardığı'), findsNothing);
    expect(find.text('TASLAK'), findsNothing);
  });

  testWidgets('shows the confidence warning for an unsuccessful parse', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseScreen(
          scanReceipt: (_) async => 'bozuk OCR',
          parseReceipt: (_) async => const ReceiptParseResult(
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
          parseReceipt: (_) async =>
              throw const ReceiptParserException('Sunucuya ulaşılamadı'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(find.text('Gider Ekle'), findsOneWidget);
    expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
  });
}
