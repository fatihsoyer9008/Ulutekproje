import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({required this.transactions, super.key});

  final List<TransactionEntity> transactions;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final sortedTransactions = List<TransactionEntity>.of(widget.transactions)
      ..sort((first, second) => second.date.compareTo(first.date));

    final filteredTransactions = sortedTransactions.where((transaction) {
      if (_searchQuery.isEmpty) return true;

      final merchant = (transaction.merchantName ?? '').toLowerCase();
      final category = _categoryName(transaction.category).toLowerCase();
      final type = transaction.transactionType == TransactionType.income
          ? 'gelir'
          : 'gider';
      final amount = _formatFormattedAmount(transaction).toLowerCase();

      return merchant.contains(_searchQuery) ||
          category.contains(_searchQuery) ||
          type.contains(_searchQuery) ||
          amount.contains(_searchQuery);
    }).toList();

    final groupedTransactions = _groupTransactions(filteredTransactions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      children: [
        // Modern Arama Çubuğu
        TextField(
          controller: _searchController,
          style: TextStyle(color: scheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.search_rounded,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 46,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.cancel_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            hintText: 'Hareketlerde ara...',
            hintStyle: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: .7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: scheme.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: scheme.primary.withValues(alpha: .5),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (sortedTransactions.isEmpty)
          const AppCard(
            child: Center(child: Text('Henüz hesap hareketi bulunmuyor.')),
          )
        else if (filteredTransactions.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Aramanızla eşleşen işlem bulunamadı.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          for (final group in groupedTransactions.entries) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 22, bottom: 8),
              child: Text(
                group.key,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
              ),
            ),
            for (final transaction in group.value) ...[
              _TransactionTile(transaction: transaction),
              const SizedBox(height: 10),
            ],
          ],
      ],
    );
  }

  Map<String, List<TransactionEntity>> _groupTransactions(
    List<TransactionEntity> transactions,
  ) {
    final Map<String, List<TransactionEntity>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final transaction in transactions) {
      final itemDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      String groupKey;
      if (itemDate == today) {
        groupKey = 'Bugün';
      } else if (itemDate == yesterday) {
        groupKey = 'Dün';
      } else if (itemDate.year == now.year && itemDate.month == now.month) {
        groupKey = 'Bu Ay';
      } else if (itemDate.year == now.year) {
        final monthName = DateFormat('MMMM', 'tr_TR').format(transaction.date);
        groupKey = '${monthName[0].toUpperCase()}${monthName.substring(1)}';
      } else {
        groupKey = DateFormat('MMMM y', 'tr_TR').format(transaction.date);
      }

      grouped.putIfAbsent(groupKey, () => []).add(transaction);
    }

    return grouped;
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = transaction.transactionType == TransactionType.income;

    final avatarBg = isIncome
        ? AppColors.mint.withValues(alpha: 0.25)
        : AppColors.lavender.withValues(alpha: 0.30);

    final formattedAmount = _formatFormattedAmount(transaction);
    final amountColor = isIncome ? AppColors.income : AppColors.expense;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarBg,
            child: Icon(
              _categoryIcon(transaction),
              size: 20,
              color: amountColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchantName ?? (isIncome ? 'Gelir' : 'Gider'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isIncome ? 'Gelir' : _categoryName(transaction.category)}'
                  ' • ${DateFormat('d MMM, HH:mm', 'tr_TR').format(transaction.date)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: .80),
                        fontWeight: FontWeight.w400,
                      ),
                ),
              ],
            ),
          ),
          // Testlerin aradığı tam formatı (+₺1.000,00 veya -₺100,00) sağlayan Text Widget'ı
          Text(
            formattedAmount,
            key: Key('transaction_amount_${transaction.id}'),
            style: TextStyle(
              color: amountColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// Testin birebir beklediği formatlama: +₺1.000,00 veya -₺100,00
String _formatFormattedAmount(TransactionEntity transaction) {
  final isIncome = transaction.transactionType == TransactionType.income;
  final prefix = isIncome ? '+' : '-';
  
  final rawAmount = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '',
    decimalDigits: 2,
  ).format(transaction.amountInMinor / 100).trim();

  return '$prefix₺$rawAmount';
}

String _categoryName(TransactionCategory category) => switch (category) {
      TransactionCategory.market => 'Market',
      TransactionCategory.ulasim => 'Ulaşım',
      TransactionCategory.fatura => 'Fatura',
      TransactionCategory.eglence => 'Eğlence',
      TransactionCategory.saglik => 'Sağlık',
      TransactionCategory.giyim => 'Giyim',
      TransactionCategory.diger => 'Diğer',
    };

IconData _categoryIcon(TransactionEntity transaction) {
  if (transaction.transactionType == TransactionType.income) {
    return Icons.trending_up_rounded;
  }

  return switch (transaction.category) {
    TransactionCategory.market => Icons.shopping_basket_outlined,
    TransactionCategory.ulasim => Icons.directions_bus_outlined,
    TransactionCategory.fatura => Icons.receipt_long_outlined,
    TransactionCategory.eglence => Icons.movie_outlined,
    TransactionCategory.saglik => Icons.health_and_safety_outlined,
    TransactionCategory.giyim => Icons.checkroom_outlined,
    TransactionCategory.diger => Icons.payments_outlined,
  };
}