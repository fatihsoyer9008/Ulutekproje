import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import '../screens/calendar_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/expense_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/transactions_screen.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({
    required this.transactions,
    this.saveTransaction,
    this.scanReceipt,
    this.parseReceipt,
    this.onProfilePressed,
    super.key,
  });

  final List<TransactionEntity> transactions;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler? parseReceipt;
  final VoidCallback? onProfilePressed;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _index = 0;
  final Set<int> _visitedIndices = {0};

  static const _titles = [
    'Günaydın, Deniz',
    'İstatistikler',
    'Kumbaralarım',
    'Finans Takvimi',
    'Hesap Hareketleri',
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        transactions: widget.transactions,
        saveTransaction: widget.saveTransaction,
        scanReceipt: widget.scanReceipt,
        parseReceipt: widget.parseReceipt,
      ),
      StatisticsScreen(transactions: widget.transactions),
      const SavingsScreen(),
      const CalendarScreen(),
      TransactionsScreen(transactions: widget.transactions),
    ];

    return AppShell(
      title: _titles[_index],
      currentIndex: _index,
      onDestinationSelected: (value) {
        if (value == _index) return;
        setState(() {
          _index = value;
          _visitedIndices.add(value);
        });
      },
      onProfilePressed: widget.onProfilePressed,
      body: IndexedStack(
        index: _index,
        children: List.generate(
          screens.length,
          (index) => _visitedIndices.contains(index)
              ? screens[index]
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
