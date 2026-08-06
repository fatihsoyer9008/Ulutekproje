import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/notifications/reminder_settings_screen.dart';
import 'expense_screen.dart';
import 'income_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.transactions,
    this.saveTransaction,
    this.scanReceipt,
    this.parseReceipt,
    this.parseReceiptImage,
    this.onAiAssistantPressed,
    super.key,
  });

  final List<TransactionEntity> transactions;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler? parseReceipt;

  final ReceiptImageParseHandler? parseReceiptImage;

  final VoidCallback? onAiAssistantPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        const Text('Finansal durumun'),
        Text(
          'Kontrol sende.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 22),
        _BalanceCard(transactions: transactions),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PrimaryActionButton(
                key: const Key('dashboard_income_action'),
                label: 'Gelir Gir',
                icon: Icons.south_west_rounded,
                onPressed: () => _open(
                  context,
                  IncomeScreen(saveTransaction: saveTransaction),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryActionButton(
                key: const Key('dashboard_expense_action'),
                label: 'Gider Gir',
                icon: Icons.north_east_rounded,
                isPrimary: false,
                onPressed: () => _open(
                  context,
                  ExpenseScreen(
                    saveTransaction: saveTransaction,
                    scanReceipt: scanReceipt,
                    parseReceipt: parseReceipt,
                    parseReceiptImage: parseReceiptImage,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'AI Finans Asistanı',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap: onAiAssistantPressed,
          color: isDark ? scheme.surfaceContainerHigh : AppColors.mintLight,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: const Icon(Icons.auto_awesome_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finansını birlikte yorumlayalım',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Harcamalarını sor, anında kişisel içgörüler al.',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Hatırlatıcı', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _open(context, const ReminderSettingsScreen()),
          child: AppCard(
            color: isDark ? scheme.surfaceContainerHigh : AppColors.mintLight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.mint,
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Günlük harcama hatırlatıcısı',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Her akşam harcamalarını girmek için bir hatırlatma saati belirle.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.transactions});

  final List<TransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    final totalInMinor = transactions.fold<int>(
      0,
      (total, item) =>
          total +
          (item.transactionType == TransactionType.income
              ? item.amountInMinor
              : -item.amountInMinor),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40276B5A),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOPLAM BAKİYE',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatTry(totalInMinor),
            key: const Key('total_balance'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Tüm işlemlerden hesaplandı',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  static String _formatTry(int amountInMinor) {
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    ).format(amountInMinor / 100);
  }
}
