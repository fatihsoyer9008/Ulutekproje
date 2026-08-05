import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import '../screens/calendar_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/expense_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/transactions_screen.dart';
import '../widgets/app_drawer.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({
    required this.transactions,
    this.greetingName = 'Kullanıcı',
    this.saveTransaction,
    this.scanReceipt,
    this.parseReceipt,
    this.parseReceiptImage,
    this.onProfilePressed,
    this.pendingOfflineTaskCount = 0,
    this.enableAccountMenu = false,
    super.key,
  });

  final List<TransactionEntity> transactions;
  final String greetingName;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler? parseReceipt;
  final ReceiptImageParseHandler? parseReceiptImage;
  final VoidCallback? onProfilePressed;
  final int pendingOfflineTaskCount;
  final bool enableAccountMenu;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _index = 0;
  final Set<int> _visitedIndices = {0};
  final StatisticsScreenController _statisticsController =
      StatisticsScreenController();

  List<String> get _titles => [
    'Günaydın, ${widget.greetingName}',
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
        parseReceiptImage: widget.parseReceiptImage,
      ),
      StatisticsScreen(
        controller: _statisticsController,
        transactions: widget.transactions,
      ),
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
      drawer: widget.enableAccountMenu
          ? AppDrawer(onProfilePressed: widget.onProfilePressed ?? () {})
          : null,
      notificationCount: widget.pendingOfflineTaskCount,
      onNotificationsPressed: () => _showSynchronizationStatus(context),
      onAiAssistantPressed: _index == 1
          ? _statisticsController.showSummary
          : null,
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

  void _showSynchronizationStatus(BuildContext context) {
    final pendingCount = widget.pendingOfflineTaskCount;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: pendingCount > 0
                    ? AppColors.warning.withValues(alpha: .14)
                    : AppColors.mint,
                child: Icon(
                  pendingCount > 0
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done_outlined,
                  color: pendingCount > 0
                      ? AppColors.warning
                      : AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                pendingCount > 0
                    ? 'Senkronizasyon bekliyor'
                    : 'Senkronizasyon tamamlandı',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                pendingCount > 0
                    ? '$pendingCount adet fiş senkronize edilmeyi bekliyor.'
                    : 'Tüm verileriniz eşitlendi.',
                key: const Key('synchronization_status_message'),
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
