import 'package:finance_database/finance_database.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import '../screens/calendar_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/expense_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/transactions_screen.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({
    required this.transactionStream,
    this.saveTransaction,
    this.scanReceipt,
    super.key,
  });

  final Stream<List<TransactionEntity>> transactionStream;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _index = 0;
  late Stream<List<TransactionEntity>> _transactionStream;
  static const _titles = [
    'Günaydın, Deniz',
    'İstatistikler',
    'Kumbaralarım',
    'Finans Takvimi',
    'Hesap Hareketleri',
  ];

  @override
  void initState() {
    super.initState();
    _transactionStream = _asBroadcastStream(widget.transactionStream);
  }

  @override
  void didUpdateWidget(covariant FinanceHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactionStream != widget.transactionStream) {
      _transactionStream = _asBroadcastStream(widget.transactionStream);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        transactionStream: _transactionStream,
        saveTransaction: widget.saveTransaction,
        scanReceipt: widget.scanReceipt,
      ),
      StatisticsScreen(transactionStream: _transactionStream),
      const SavingsScreen(),
      const CalendarScreen(),
      TransactionsScreen(transactionStream: _transactionStream),
    ];

    return AppShell(
      title: _titles[_index],
      currentIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      body: IndexedStack(index: _index, children: screens),
    );
  }

  static Stream<List<TransactionEntity>> _asBroadcastStream(
    Stream<List<TransactionEntity>> stream,
  ) => stream.isBroadcast ? stream : stream.asBroadcastStream();
}
