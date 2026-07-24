import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import '../screens/calendar_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/transactions_screen.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({super.key});
  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _index = 0;
  static const _titles = ['Günaydın, Deniz', 'İstatistikler', 'Kumbaralarım', 'Finans Takvimi', 'Hesap Hareketleri'];
  static const _screens = [DashboardScreen(), StatisticsScreen(), SavingsScreen(), CalendarScreen(), TransactionsScreen()];
  @override
  Widget build(BuildContext context) => AppShell(
        title: _titles[_index],
        currentIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        body: IndexedStack(index: _index, children: _screens),
      );
}
