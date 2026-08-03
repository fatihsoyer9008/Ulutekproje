import 'dart:io';

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

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');

    final baseDirectory = await getTemporaryDirectory();
    tempDirectory = await Directory(
      '${baseDirectory.path}/isar_dashboard_flow_${DateTime.now().microsecondsSinceEpoch}',
    ).create();

    isar = await Isar.open(
      [TransactionEntitySchema, ReceiptLineItemEntitySchema],
      directory: tempDirectory!.path,
      name: 'isar_dashboard_flow',
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
    'gelirden sonra eklenen gider Dashboard ve Hesap Hareketlerinde görünür',
    (tester) async {
      // Başlangıç bakiyesi: +₺100,00
      await repository.addTransaction(_income('Başlangıç Geliri', 10000));

      await tester.pumpWidget(
        FinanceApp(
          transactionStream: repository.watchAllTransactions(),
          saveTransaction: (transaction) async {
            await repository.addTransaction(transaction);
          },
          // Testte kamera ekranının otomatik açılmasını önler.
          scanReceipt: (_) async => null,
        ),
      );

      await _pumpUntilTextContains(
        tester,
        const Key('total_balance'),
        '100,00',
      );

      expect(_textOf(tester, const Key('total_balance')), contains('100,00'));

      // Uygulama arayüzünden gider ekle.
      await tester.tap(find.text('Gider Gir'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('manual_entry_button')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('institution_name_field')),
        'Entegrasyon Test Market',
      );
      await tester.tap(find.byKey(const Key('category_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Market').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('amount_field')), '25,00');

      await tester.tap(find.byKey(const Key('confirm_draft_button')));

      // Kaydın ardından Dashboard'a dönülmeli ve bakiye ₺25 azalmalı.
      await _pumpUntilTextContains(tester, const Key('total_balance'), '75,00');

      expect(_textOf(tester, const Key('total_balance')), contains('75,00'));

      // Hesap Hareketleri sekmesinde yeni gider görünmeli.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.receipt_long_outlined),
        ),
      );

      await _pumpUntilFound(tester, find.text('Entegrasyon Test Market'));

      expect(find.text('-₺25,00'), findsOneWidget);

      // Veritabanında yalnızca bir gider kaydı bulunmalı.
      final allTransactions = await repository.getAllTransactions();
      final expenses = allTransactions
          .where(
            (transaction) =>
                transaction.transactionType == TransactionType.expense,
          )
          .toList();

      expect(expenses, hasLength(1));
      expect(expenses.single.merchantName, 'Entegrasyon Test Market');
      expect(expenses.single.amountInMinor, 2500);
    },
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));

    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  throw TestFailure('Beklenen öğe bulunamadı: $finder');
}

String _textOf(WidgetTester tester, Key key) {
  final text = tester.widget<Text>(find.byKey(key));
  return text.data ?? '';
}

Future<void> _pumpUntilTextContains(
  WidgetTester tester,
  Key key,
  String expected,
) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));

    final finder = find.byKey(key);
    if (finder.evaluate().isNotEmpty &&
        _textOf(tester, key).contains(expected)) {
      return;
    }
  }

  throw TestFailure('Beklenen metin bulunamadı: key=$key, expected=$expected');
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
