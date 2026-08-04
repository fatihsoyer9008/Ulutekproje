import 'package:app_main/features/transaction_draft/presentation/receipt_items_review_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openPage(
    WidgetTester tester, {
    List<ReceiptItem> items = const [],
    int? receiptTotalInMinor,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: themeMode,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open_review_button'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<ReceiptItemsReviewResult>(
                  builder: (_) => ReceiptItemsReviewPage(
                    initialItems: items,
                    receiptTotalInMinor: receiptTotalInMinor,
                  ),
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_review_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('boş durumda ürün eklenebilir', (tester) async {
    await openPage(tester, receiptTotalInMinor: 2500);
    expect(find.byKey(const Key('receipt_items_empty_state')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_receipt_item_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('receipt_item_name_field')),
      'Süt',
    );
    await tester.enterText(
      find.byKey(const Key('receipt_item_quantity_field')),
      '2',
    );
    await tester.enterText(
      find.byKey(const Key('receipt_item_unit_price_field')),
      '12,50',
    );
    await tester.tap(find.byKey(const Key('save_receipt_item_button')));
    await tester.pumpAndSettle();

    expect(find.text('Süt'), findsOneWidget);
    expect(find.text('Satır toplamı: 25,00 TL'), findsOneWidget);
  });

  testWidgets('ürün düzenlenir ve silme onayı alınır', (tester) async {
    await openPage(
      tester,
      items: const [
        ReceiptItem(
          name: 'Ekmek',
          quantity: 1,
          unitPriceInMinor: 1000,
          totalAmountInMinor: 1000,
        ),
      ],
      receiptTotalInMinor: 1000,
    );

    await tester.tap(find.byKey(const Key('edit_receipt_item_0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('receipt_item_name_field')),
      'Tam Buğday Ekmek',
    );
    await tester.tap(find.byKey(const Key('save_receipt_item_button')));
    await tester.pumpAndSettle();
    expect(find.text('Tam Buğday Ekmek'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_receipt_item_0')));
    await tester.pumpAndSettle();
    expect(find.text('Ürün silinsin mi?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('confirm_delete_receipt_item_button')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt_items_empty_state')), findsOneWidget);
  });

  testWidgets('uyuşmazlıkta fiş tutarı açık onayla güncellenir', (
    tester,
  ) async {
    await openPage(
      tester,
      items: const [
        ReceiptItem(name: 'Kahve', totalAmountInMinor: 3000),
      ],
      receiptTotalInMinor: 2500,
    );
    expect(
      find.byKey(const Key('receipt_items_mismatch_warning')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('use_receipt_items_total_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_use_items_total_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('receipt_items_mismatch_warning')),
      findsNothing,
    );
  });

  testWidgets('eksik ürün alanlarını güvenli biçimde gösterir', (
    tester,
  ) async {
    await openPage(
      tester,
      items: const [ReceiptItem(name: 'Tanımsız ürün')],
      receiptTotalInMinor: 1000,
    );

    expect(find.text('Miktar: Belirtilmedi'), findsOneWidget);
    expect(find.text('Birim fiyat: Belirtilmedi'), findsOneWidget);
    expect(find.text('Satır toplamı: Belirtilmedi'), findsOneWidget);
  });

  testWidgets('boş ad, sıfır miktar ve negatif fiyat kaydedilemez', (
    tester,
  ) async {
    await openPage(tester);
    await tester.tap(find.byKey(const Key('add_receipt_item_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('receipt_item_quantity_field')),
      '0',
    );
    await tester.enterText(
      find.byKey(const Key('receipt_item_unit_price_field')),
      '-1',
    );
    final priceField = tester.widget<TextFormField>(
      find.byKey(const Key('receipt_item_unit_price_field')),
    );
    expect(priceField.controller?.text, isNot(contains('-')));
    await tester.enterText(
      find.byKey(const Key('receipt_item_unit_price_field')),
      '',
    );
    await tester.tap(find.byKey(const Key('save_receipt_item_button')));
    await tester.pump();

    expect(find.text('Ürün adı zorunludur'), findsOneWidget);
    expect(find.text('Miktar sıfırdan büyük olmalıdır'), findsOneWidget);
    expect(find.text('Geçerli bir tutar giriniz'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('ürün işlemlerinin erişilebilirlik etiketleri bulunur', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openPage(
      tester,
      items: const [
        ReceiptItem(
          name: 'Süt',
          quantity: 2,
          unitPriceInMinor: 1250,
          totalAmountInMinor: 2500,
        ),
      ],
      receiptTotalInMinor: 2500,
    );

    expect(
      tester.getSemantics(find.byKey(const Key('receipt_item_0'))).label,
      contains('Süt'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('edit_receipt_item_0')))
          .tooltip,
      'Süt ürününü düzenle',
    );
    semantics.dispose();
  });

  testWidgets('vazgeçmek null sonuç döndürür', (tester) async {
    ReceiptItemsReviewResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<ReceiptItemsReviewResult>(
                  builder: (_) => const ReceiptItemsReviewPage(
                    initialItems: [],
                    receiptTotalInMinor: 1000,
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
    await tester.tap(find.byKey(const Key('cancel_receipt_items_button')));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('küçük ekranda, klavyede ve koyu temada taşma olmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openPage(
      tester,
      themeMode: ThemeMode.dark,
      items: const [
        ReceiptItem(
          name: 'Uzun isimli market ürünü',
          quantity: 2,
          unitPriceInMinor: 1250,
          totalAmountInMinor: 2500,
        ),
      ],
      receiptTotalInMinor: 2500,
    );
    await tester.tap(find.byKey(const Key('add_receipt_item_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receipt_item_name_field')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
