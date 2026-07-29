import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({required this.transactionStream, super.key});

  final Stream<List<TransactionEntity>> transactionStream;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TransactionEntity>>(
    stream: transactionStream,
    builder: (context, snapshot) {
      final transactions = List<TransactionEntity>.of(snapshot.data ?? const [])
        ..sort((first, second) => second.date.compareTo(first.date));

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        children: [
          const TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Hareketlerde ara...',
            ),
          ),
          const SizedBox(height: 20),
          Text('Tüm İşlemler', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (snapshot.hasError)
            const AppCard(
              child: Center(child: Text('Hesap hareketleri yüklenemedi.')),
            )
          else if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (transactions.isEmpty)
            const AppCard(
              child: Center(child: Text('Henüz hesap hareketi bulunmuyor.')),
            )
          else
            for (final transaction in transactions) ...[
              _TransactionTile(transaction: transaction),
              const SizedBox(height: 10),
            ],
        ],
      );
    },
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.transactionType == TransactionType.income;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isIncome ? AppColors.mint : AppColors.lavender,
            child: Icon(
              isIncome ? Icons.south_west_rounded : _categoryIcon(transaction),
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchantName ?? (isIncome ? 'Gelir' : 'Gider'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${isIncome ? 'Gelir' : _categoryName(transaction.category)}'
                  ' • ${DateFormat('d MMM y, HH:mm', 'tr_TR').format(transaction.date)}',
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${_formatTry(transaction.amountInMinor)}',
            key: Key('transaction_amount_${transaction.id}'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTry(int amountInMinor) => NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
).format(amountInMinor / 100);

String _categoryName(TransactionCategory category) => switch (category) {
  TransactionCategory.market => 'Market',
  TransactionCategory.ulasim => 'Ulaşım',
  TransactionCategory.fatura => 'Fatura',
  TransactionCategory.eglence => 'Eğlence',
  TransactionCategory.saglik => 'Sağlık',
  TransactionCategory.giyim => 'Giyim',
  TransactionCategory.diger => 'Diğer',
};

IconData _categoryIcon(TransactionEntity transaction) =>
    switch (transaction.category) {
      TransactionCategory.market => Icons.shopping_basket_outlined,
      TransactionCategory.ulasim => Icons.directions_bus_outlined,
      TransactionCategory.fatura => Icons.receipt_long_outlined,
      TransactionCategory.eglence => Icons.movie_outlined,
      TransactionCategory.saglik => Icons.health_and_safety_outlined,
      TransactionCategory.giyim => Icons.checkroom_outlined,
      TransactionCategory.diger => Icons.payments_outlined,
    };
