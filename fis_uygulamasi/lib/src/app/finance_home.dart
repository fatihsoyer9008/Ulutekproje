import 'dart:math';

import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import '../../features/ai_assistant/presentation/assistant_access_gate.dart';
import '../../features/ai_assistant/domain/ai_assistant_message_stream.dart';
import '../../features/ai_assistant/presentation/ai_assistant_sheet.dart';
import '../screens/calendar_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/expense_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/transactions_screen.dart';
import '../widgets/app_drawer.dart';
import 'time_aware_greeting.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({
    required this.transactions,
    this.greetingName = 'Kullanıcı',
    this.saveTransaction,
    this.scanReceipt,
    this.parseReceipt,
    this.parseReceiptImage,
    this.onProfilePressed,
    this.onGroupsPressed,
    this.pendingOfflineTaskCount = 0,
    this.enableAccountMenu = false,
    this.enablePersistentSavings = false,
    this.aiAssistantMessageStream,
    this.aiAssistantAccessGate,
    super.key,
  });

  final List<TransactionEntity> transactions;
  final String greetingName;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler? parseReceipt;
  final ReceiptImageParseHandler? parseReceiptImage;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onGroupsPressed;
  final int pendingOfflineTaskCount;
  final bool enableAccountMenu;
  final bool enablePersistentSavings;
  final AiAssistantMessageStream? aiAssistantMessageStream;
  final AiAssistantAccessGate? aiAssistantAccessGate;
  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _index = 0;
  bool _isPreparingAssistant = false;
  final Set<int> _visitedIndices = {0};
  final Random _greetingRandom = Random();
  final StatisticsScreenController _statisticsController =
      StatisticsScreenController();
  late DateTime _greetingLocalTime;
  late String _homeGreeting;

  List<String> get _titles => [
    _homeGreeting,
    'İstatistikler',
    'Kumbaralarım',
    'Finans Takvimi',
    'Hesap Hareketleri',
  ];

  @override
  void initState() {
    super.initState();
    _updateGreeting();
  }

  @override
  void didUpdateWidget(covariant FinanceHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.greetingName != widget.greetingName) {
      _updateGreeting();
    }
  }

  @override
  Widget build(BuildContext context) {
    _refreshGreetingWhenNeeded();
    final screens = [
      DashboardScreen(
        transactions: widget.transactions,
        saveTransaction: widget.saveTransaction,
        scanReceipt: widget.scanReceipt,
        parseReceipt: widget.parseReceipt,

        parseReceiptImage: widget.parseReceiptImage,
        onAiAssistantPressed: _showAiAssistant,
      ),
      StatisticsScreen(
        controller: _statisticsController,
        transactions: widget.transactions,
      ),

      widget.enablePersistentSavings
          ? const SavingsScreen.live()
          : const SavingsScreen(),
      CalendarScreen(transactions: widget.transactions),
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
          ? AppDrawer(
              onProfilePressed: widget.onProfilePressed ?? () {},
              onGroupsPressed: widget.onGroupsPressed,
            )
          : null,
      notificationCount: widget.pendingOfflineTaskCount,
      onNotificationsPressed: () => _showSynchronizationStatus(context),
      onAiAssistantPressed: _showAiAssistant,
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

  void _refreshGreetingWhenNeeded() {
    final now = DateTime.now();
    final dayChanged =
        now.year != _greetingLocalTime.year ||
        now.month != _greetingLocalTime.month ||
        now.day != _greetingLocalTime.day;
    final periodChanged =
        TimeAwareGreeting.periodFor(now) !=
        TimeAwareGreeting.periodFor(_greetingLocalTime);
    if (dayChanged || periodChanged) _updateGreeting(now);
  }

  void _updateGreeting([DateTime? localTime]) {
    _greetingLocalTime = localTime ?? DateTime.now();
    _homeGreeting = TimeAwareGreeting.compose(
      name: widget.greetingName,
      localTime: _greetingLocalTime,
      random: _greetingRandom,
    );
  }

  Future<void> _showAiAssistant() async {
    if (_isPreparingAssistant) return;
    _isPreparingAssistant = true;

    try {
      final accessGate = widget.aiAssistantAccessGate;
      if (accessGate != null) {
        final allowed = await accessGate.ensureAccess(context);
        if (!allowed || !mounted) return;
      }

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 720),
        builder: (_) => FractionallySizedBox(
          heightFactor: .9,
          child: AiAssistantSheet(
            transactions: widget.transactions,
            messageStream: widget.aiAssistantMessageStream,
          ),
        ),
      );
    } finally {
      _isPreparingAssistant = false;
    }
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
