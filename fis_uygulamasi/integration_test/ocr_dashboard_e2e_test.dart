import 'dart:async';
import 'dart:io';

import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/src/app/finance_app.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory? tempDirectory;
  Isar? isar;
  late TransactionRepository repository;

  const rawOcrText = 'MIGROS\nTOPLAM 25,50 TL';
  final updatedDate = DateTime(2026, 8, 2);
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');

    final baseDirectory = await getTemporaryDirectory();
    tempDirectory = await Directory(
      '${baseDirectory.path}/ocr_dashboard_e2e_'
      '${DateTime.now().microsecondsSinceEpoch}',
    ).create();

    isar = await Isar.open(
      [TransactionEntitySchema],
      directory: tempDirectory!.path,
      name: 'ocr_dashboard_e2e',
    );

    repository = TransactionRepository(isar!);
  });

  tearDownAll(() async {
    await isar?.close(deleteFromDisk: true);

    final directory = tempDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  testWidgets(
    'OCR sonucu onaylanınca Isar, Dashboard ve Hesap Hareketlerine yansır',
    (tester) async {
      // Dashboard bakiyesinin değişimini ölçmek için başlangıç geliri eklenir.
      await repository.addTransaction(_income('Başlangıç Geliri', 10000));

      final parserResponse = Completer<ReceiptParseResult>();
      String? sentOcrText;
      final backendResponse = <String, dynamic>{
        'normalized_ocr_text': 'MIGROS\nTOPLAM 20,00 TL',
        'merchant': 'MIGROS',
        'total_amount_minor': 2000,
        'currency': 'TRY',
        'date': '2026-08-01T00:00:00.000',
        'category': 'Market',
        'confidence_score': 0.92,
        'is_parse_successful': true,
        'items': <dynamic>[],
      };
      await tester.pumpWidget(
        FinanceApp(
          transactionStream: repository.watchAllTransactions(),
          saveTransaction: repository.addTransaction,
          scanReceipt: (_) async => rawOcrText,
          parseReceipt: (text, {cancelToken}) {
            sentOcrText = text;
            return parserResponse.future;
          },
        ),
      );

      await _pumpUntilTextContains(
        tester,
        const Key('total_balance'),
        '100,00',
      );

      // OCR akışı başlatılır; backend yanıtı henüz dönmediği için loading görünür.
      await tester.tap(find.text('Gider Gir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ocr_camera_button')));

      await _pumpUntilFound(
        tester,
        find.byKey(const Key('receipt_analysis_page')),
      );

      expect(sentOcrText, rawOcrText);
      expect(find.text('Fişiniz inceleniyor...'), findsOneWidget);
      // Kullanıcı onaylamadan Isar'a yeni gider kaydı yazılmamalıdır.
      final beforeConfirmation = await repository.getAllTransactions();
      expect(beforeConfirmation, hasLength(1));

      // Sahte backend cevabı döndürülür.
      parserResponse.complete(ReceiptParseResult.fromJson(backendResponse));

      await _pumpUntilFound(tester, find.text('İşlemi Kontrol Et'));

      // Backend’den gelen kurum, kategori, tutar ve tarih onay ekranında görünür.
      expect(find.widgetWithText(TextFormField, 'MIGROS'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '20,00'), findsOneWidget);

      final categoryField = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('category_field')),
      );
      expect(categoryField.initialValue, 'Market');

      final dateField = tester.widget<TextFormField>(
        find.byKey(const Key('transaction_date_field')),
      );
      expect(dateField.controller?.text, '01.08.2026');

      // Kullanıcı kurum ve tutarı düzenler.
      await tester.enterText(
        find.byKey(const Key('institution_name_field')),
        'E2E Test Market',
      );
      await tester.enterText(find.byKey(const Key('amount_field')), '25,50');

      // Kullanıcı fiş tarihini düzenler.
      await tester.tap(find.byKey(const Key('transaction_date_field')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      final dialogContext = tester.element(find.byType(DatePickerDialog));
      Navigator.of(dialogContext).pop(updatedDate);
      await tester.pumpAndSettle();

      final updatedDateField = tester.widget<TextFormField>(
        find.byKey(const Key('transaction_date_field')),
      );
      expect(updatedDateField.controller?.text, '02.08.2026');

      // Aynı butona hızlıca iki kez basılır; yalnızca tek kayıt oluşmalıdır.
      final confirmButton = find.byKey(const Key('confirm_draft_button'));
      await tester.tap(confirmButton);
      await tester.tap(confirmButton);

      // Onay sayfası kapanır ve Dashboard bakiyesi 25,50 TL azalır.
      await _pumpUntilTextContains(tester, const Key('total_balance'), '74,50');

      await _pumpUntilAbsent(tester, find.text('İşlemi Kontrol Et'));
      expect(_textOf(tester, const Key('total_balance')), contains('74,50'));

      // Isar kaydının alanları doğrulanır.
      final allTransactions = await repository.getAllTransactions();
      final expenses = allTransactions
          .where(
            (transaction) =>
                transaction.transactionType == TransactionType.expense,
          )
          .toList();

      expect(expenses, hasLength(1));

      final expense = expenses.single;
      expect(expense.merchantName, 'E2E Test Market');
      expect(expense.amountInMinor, 2550);
      expect(expense.transactionType, TransactionType.expense);
      expect(expense.source, TransactionSource.ocrLlm);
      expect(expense.rawOcrText, rawOcrText);
      expect(expense.date, updatedDate);

      // Hesap Hareketleri ekranında yeni işlem görünür.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.receipt_long_outlined),
        ),
      );

      await _pumpUntilFound(tester, find.text('E2E Test Market'));

      expect(find.text('E2E Test Market'), findsOneWidget);
      expect(find.text('-₺25,50'), findsOneWidget);
    },
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));

    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  throw TestFailure('Beklenen öğe bulunamadı: $finder');
}

Future<void> _pumpUntilAbsent(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));

    if (finder.evaluate().isEmpty) {
      return;
    }
  }

  throw TestFailure('Öğe ekrandan kaybolmadı: $finder');
}

Future<void> _pumpUntilTextContains(
  WidgetTester tester,
  Key key,
  String expected,
) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));

    final finder = find.byKey(key);
    if (finder.evaluate().isNotEmpty &&
        _textOf(tester, key).contains(expected)) {
      return;
    }
  }

  throw TestFailure('Beklenen metin bulunamadı: key=$key, expected=$expected');
}

String _textOf(WidgetTester tester, Key key) {
  final text = tester.widget<Text>(find.byKey(key));
  return text.data ?? '';
}

TransactionEntity _income(String merchant, int amountInMinor) {
  final now = DateTime.now();

  return TransactionEntity()
    ..transactionType = TransactionType.income
    ..amountInMinor = amountInMinor
    ..category = TransactionCategory.diger
    ..date = now
    ..merchantName = merchant
    ..source = TransactionSource.manual
    ..createdAt = now
    ..updatedAt = now;
}
