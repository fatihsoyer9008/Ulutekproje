import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ui_models.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({
    super.key,
    this.categories = const [],
    this.monthlySpending = const [],
    this.transactionStream,
  });

  final List<CategorySummary> categories;
  final List<MonthlySpending> monthlySpending;
  final Stream<List<TransactionEntity>>? transactionStream;

  @override
  Widget build(BuildContext context) {
    final stream = transactionStream;
    if (stream == null) {
      return _StatisticsContent(
        categories: categories,
        monthlySpending: monthlySpending,
      );
    }

    return StreamBuilder<List<TransactionEntity>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('İstatistikler yüklenemedi.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final expenses = snapshot.data!
            .where(
              (transaction) =>
                  transaction.transactionType == TransactionType.expense,
            )
            .toList();
        return _StatisticsContent(
          categories: _categorySummaries(expenses),
          monthlySpending: _monthlySpending(expenses),
        );
      },
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({
    required this.categories,
    required this.monthlySpending,
  });

  final List<CategorySummary> categories;
  final List<MonthlySpending> monthlySpending;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Genel İstatistik',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Son 6 aylık harcama eğilimi'),
            ],
          ),
          const Chip(label: Text('6 Ay')),
        ],
      ),
      const SizedBox(height: 16),
      if (monthlySpending.isEmpty)
        const AppCard(
          child: Center(child: Text('Henüz harcama verisi bulunmuyor.')),
        )
      else
        AppCard(
          padding: const EdgeInsets.fromLTRB(10, 24, 18, 12),
          child: SizedBox(
            height: 230,
            child: _Chart(monthlySpending: monthlySpending),
          ),
        ),
      const SizedBox(height: 28),
      Text('Kategoriler', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (categories.isEmpty)
        const AppCard(
          child: Center(child: Text('Henüz kategori verisi bulunmuyor.')),
        ),
      ...categories.map(
        (category) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Category(category: category),
        ),
      ),
    ],
  );
}

List<MonthlySpending> _monthlySpending(List<TransactionEntity> transactions) {
  if (transactions.isEmpty) return const [];

  final now = DateTime.now();
  return [
    for (var monthOffset = 5; monthOffset >= 0; monthOffset--)
      _monthlyTotal(transactions, DateTime(now.year, now.month - monthOffset)),
  ];
}

MonthlySpending _monthlyTotal(
  List<TransactionEntity> transactions,
  DateTime month,
) {
  final total = transactions
      .where(
        (transaction) =>
            transaction.date.year == month.year &&
            transaction.date.month == month.month,
      )
      .fold<int>(0, (sum, transaction) => sum + transaction.amountInMinor);
  return MonthlySpending(DateFormat.MMM('tr_TR').format(month), total);
}

List<CategorySummary> _categorySummaries(List<TransactionEntity> transactions) {
  if (transactions.isEmpty) return const [];

  final totals = <TransactionCategory, int>{};
  for (final transaction in transactions) {
    totals.update(
      transaction.category,
      (total) => total + transaction.amountInMinor,
      ifAbsent: () => transaction.amountInMinor,
    );
  }
  final overallTotal = totals.values.fold<int>(0, (sum, value) => sum + value);
  final summaries = [
    for (final entry in totals.entries)
      CategorySummary(
        _categoryName(entry.key),
        _formatTry(entry.value),
        overallTotal == 0 ? 0 : entry.value / overallTotal,
        _categoryColor(entry.key),
        _categoryIcon(entry.key),
      ),
  ];
  summaries.sort((first, second) => second.progress.compareTo(first.progress));
  return summaries;
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

Color _categoryColor(TransactionCategory category) => switch (category) {
  TransactionCategory.market => AppColors.primary,
  TransactionCategory.ulasim => AppColors.blue,
  TransactionCategory.fatura => AppColors.expense,
  TransactionCategory.eglence => AppColors.blue,
  TransactionCategory.saglik => AppColors.income,
  TransactionCategory.giyim => AppColors.warning,
  TransactionCategory.diger => AppColors.muted,
};

IconData _categoryIcon(TransactionCategory category) => switch (category) {
  TransactionCategory.market => Icons.shopping_basket_outlined,
  TransactionCategory.ulasim => Icons.directions_bus_outlined,
  TransactionCategory.fatura => Icons.receipt_long_outlined,
  TransactionCategory.eglence => Icons.movie_outlined,
  TransactionCategory.saglik => Icons.health_and_safety_outlined,
  TransactionCategory.giyim => Icons.checkroom_outlined,
  TransactionCategory.diger => Icons.category_outlined,
};

class _Chart extends StatelessWidget {
  const _Chart({required this.monthlySpending});

  final List<MonthlySpending> monthlySpending;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final (index, spending) in monthlySpending.indexed)
        FlSpot(index.toDouble(), spending.amountInMinor / 100),
    ];
    final highestAmount = monthlySpending.fold<double>(0, (highest, spending) {
      final amountInLira = spending.amountInMinor / 100;
      return amountInLira > highest ? amountInLira : highest;
    });

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: highestAmount == 0 ? 1 : highestAmount * 1.15,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= monthlySpending.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(monthlySpending[index].label),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 4,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.mint),
          ),
        ],
      ),
    );
  }
}

class _Category extends StatelessWidget {
  const _Category({required this.category});

  final CategorySummary category;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: category.color.withValues(alpha: .14),
          child: Icon(category.icon, color: category.color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(category.amount),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: category.progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                color: category.color,
                backgroundColor: category.color.withValues(alpha: .12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
