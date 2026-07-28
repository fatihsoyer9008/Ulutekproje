import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import '../screens/calendar_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/transactions_screen.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({required this.transactionLoader, super.key});

  final TransactionLoader transactionLoader;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _index = 0;
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
      DashboardScreen(transactionLoader: widget.transactionLoader),
      const StatisticsScreen(),
      const SavingsScreen(),
      const CalendarScreen(),
      const TransactionsScreen(),
    ];

    return AppShell(
      title: _titles[_index],
      currentIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      body: IndexedStack(index: _index, children: screens),
    );
  }
}
