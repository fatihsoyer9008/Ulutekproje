import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'expense_screen.dart';
import 'income_screen.dart';

typedef TransactionLoader = Future<List<TransactionEntity>> Function();

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.transactionLoader, super.key});

  final TransactionLoader transactionLoader;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<TransactionEntity>> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = widget.transactionLoader();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactionLoader != widget.transactionLoader) {
      _transactions = widget.transactionLoader();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
    children: [
      const Text('Finansal durumun'),
      Text('Kontrol sende.', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 22),
      _BalanceCard(transactions: _transactions),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: PrimaryActionButton(
              label: 'Gelir Gir',
              icon: Icons.south_west_rounded,
              onPressed: () => _open(context, const IncomeScreen()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryActionButton(
              label: 'Gider Gir',
              icon: Icons.north_east_rounded,
              isPrimary: false,
              onPressed: () => _open(context, const ExpenseScreen()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text('Hatırlatıcı', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      AppCard(
        color: AppColors.mintLight,
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
                    'Bu hafta 2 ödeme var',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Netflix yarın, internet faturası ise 3 gün sonra '
                    'ödenecek.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.transactions});

  final Future<List<TransactionEntity>> transactions;

  @override
  Widget build(BuildContext context) => Container(
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
            Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<TransactionEntity>>(
          future: transactions,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CircularProgressIndicator(
                    key: Key('balance_loading'),
                    color: Colors.white,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Text(
                'Bakiye yüklenemedi',
                key: Key('balance_error'),
                style: TextStyle(color: Colors.white, fontSize: 20),
              );
            }

            final totalInMinor = (snapshot.data ?? const <TransactionEntity>[])
                .fold<int>(0, (total, item) => total + item.amountInMinor);
            return Text(
              _formatTry(totalInMinor),
              key: const Key('total_balance'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            );
          },
        ),
        const SizedBox(height: 25),
        const Text(
          'Tüm işlemlerden hesaplandı',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );

  static String _formatTry(int amountInMinor) {
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    ).format(amountInMinor / 100);
  }
}
