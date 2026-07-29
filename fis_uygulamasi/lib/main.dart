import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app/finance_app.dart';
import 'src/screens/expense_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  final isar = await IsarService.getInstance();
  final transactionRepository = TransactionRepository(isar);

  runApp(
    FinanceApp(
      transactionStream: transactionRepository.watchAllTransactions(),
      saveTransaction: (transaction) async {
        await transactionRepository.addTransaction(transaction);
      },
    ),
  );
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({
    super.key,
    this.transactionStream = const Stream<List<TransactionEntity>>.empty(),
    this.saveTransaction,
    this.scanReceipt,
  });

  final Stream<List<TransactionEntity>> transactionStream;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cüzdanım',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: StreamBuilder<List<TransactionEntity>>(
      stream: transactionStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('İşlemler yüklenemedi.'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return FinanceHome(
          transactions: snapshot.requireData,
          saveTransaction: saveTransaction,
          scanReceipt: scanReceipt,
        );
      },
    ),
  );
}