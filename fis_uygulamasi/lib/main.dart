import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app/app_router.dart';
import 'src/app/finance_app.dart';
import 'src/screens/expense_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  final isar = await IsarService.getInstance();
  final transactionRepository = TransactionRepository(isar);

  runApp(
    ProviderScope(
      child: FinanceApp(
        enableAuth: true,
        transactionStream: transactionRepository.watchAllTransactions(),
        saveTransaction: transactionRepository.addTransaction,
      ),
    ),
  );
}

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({
    super.key,
    this.enableAuth = false,
    this.transactionStream = const Stream<List<TransactionEntity>>.empty(),
    this.saveTransaction,
    this.scanReceipt,
  });

  final bool enableAuth;
  final Stream<List<TransactionEntity>> transactionStream;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;

  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    if (widget.enableAuth) {
      _router = createAppRouter(
        ref: ref,
        transactionStream: widget.transactionStream,
        saveTransaction: widget.saveTransaction,
        scanReceipt: widget.scanReceipt,
      );
    }
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (widget.enableAuth && router != null) {
      return MaterialApp.router(
        title: 'Cüzdanım',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      );
    }

    // Eski widget/integration testlerinin ve bağımsız UI kullanımının
    // geriye dönük uyumluluğu korunur.
    return MaterialApp(
      title: 'Cüzdanım',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: StreamBuilder<List<TransactionEntity>>(
        stream: widget.transactionStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('İşlemler yüklenemedi.')),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return FinanceHome(
            transactions: snapshot.requireData,
            saveTransaction: widget.saveTransaction,
            scanReceipt: widget.scanReceipt,
          );
        },
      ),
    );
  }
}
