import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/ui_models.dart';

enum StatisticsPeriod {
  oneMonth('1 Ay'),
  threeMonths('3 Ay'),
  sixMonths('6 Ay'),
  oneYear('1 Yıl');

  const StatisticsPeriod(this.label);

  final String label;
}

class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.transactions,
    required this.expenses,
    required this.categories,
    required this.spending,
    required this.totalIncomeInMinor,
    required this.totalExpenseInMinor,
  });

  final List<TransactionEntity> transactions;
  final List<TransactionEntity> expenses;
  final List<CategorySummary> categories;
  final List<MonthlySpending> spending;
  final int totalIncomeInMinor;
  final int totalExpenseInMinor;

  int get netBalanceInMinor => totalIncomeInMinor - totalExpenseInMinor;
}

abstract final class StatisticsCalculator {
  static StatisticsSnapshot calculate({
    required List<TransactionEntity> transactions,
    required StatisticsPeriod period,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final filtered = filterTransactions(transactions, period, now);
    final expenses = filtered
        .where((item) => item.transactionType == TransactionType.expense)
        .toList(growable: false);
    final income = filtered
        .where((item) => item.transactionType == TransactionType.income)
        .fold<int>(0, (sum, item) => sum + item.amountInMinor);
    final expense = expenses.fold<int>(
      0,
      (sum, item) => sum + item.amountInMinor,
    );

    return StatisticsSnapshot(
      transactions: filtered,
      expenses: expenses,
      categories: categorySummaries(expenses),
      spending: spendingSeries(expenses, period, now),
      totalIncomeInMinor: income,
      totalExpenseInMinor: expense,
    );
  }

  static List<TransactionEntity> filterTransactions(
    List<TransactionEntity> transactions,
    StatisticsPeriod period,
    DateTime referenceDate,
  ) {
    final range = _rangeFor(period, referenceDate);
    return transactions
        .where(
          (item) =>
              !item.date.isBefore(range.start) && item.date.isBefore(range.end),
        )
        .toList(growable: false);
  }

  static List<MonthlySpending> spendingSeries(
    List<TransactionEntity> expenses,
    StatisticsPeriod period,
    DateTime referenceDate,
  ) {
    final today = _startOfDay(referenceDate);
    switch (period) {
      case StatisticsPeriod.oneMonth:
        final monthStart = DateTime(today.year, today.month);
        final monthEnd = DateTime(today.year, today.month + 1);
        final result = <MonthlySpending>[];
        var weekStart = monthStart;
        var week = 1;
        while (weekStart.isBefore(monthEnd)) {
          final proposedEnd = weekStart.add(const Duration(days: 7));
          final weekEnd = proposedEnd.isAfter(monthEnd)
              ? monthEnd
              : proposedEnd;
          result.add(
            MonthlySpending(
              '$week. Hafta',
              _sumBetween(expenses, weekStart, weekEnd),
            ),
          );
          weekStart = weekEnd;
          week++;
        }
        return result;
      case StatisticsPeriod.threeMonths:
        return _monthlySeries(expenses, today, 3);
      case StatisticsPeriod.sixMonths:
        return _monthlySeries(expenses, today, 6);
      case StatisticsPeriod.oneYear:
        return _monthlySeries(expenses, today, 12);
    }
  }

  static List<MonthlySpending> _monthlySeries(
    List<TransactionEntity> expenses,
    DateTime today,
    int monthCount,
  ) => List.generate(monthCount, (index) {
    final month = DateTime(today.year, today.month - (monthCount - 1 - index));
    return MonthlySpending(
      _monthLabel(month.month),
      _sumBetween(expenses, month, DateTime(month.year, month.month + 1)),
    );
  });

  static List<CategorySummary> categorySummaries(
    List<TransactionEntity> expenses,
  ) {
    if (expenses.isEmpty) return const [];

    final totals = <String, _CategoryTotal>{};
    for (final transaction in expenses) {
      final customName = transaction.categoryName?.trim();
      final name = customName == null || customName.isEmpty
          ? categoryName(transaction.category)
          : customName;
      totals.update(
        name,
        (value) => value.add(transaction.amountInMinor),
        ifAbsent: () => _CategoryTotal(
          amountInMinor: transaction.amountInMinor,
          category: transaction.category,
        ),
      );
    }

    final overall = totals.values.fold<int>(
      0,
      (sum, value) => sum + value.amountInMinor,
    );
    final summaries = totals.entries.map((entry) {
      final value = entry.value;
      return CategorySummary(
        entry.key,
        formatTry(value.amountInMinor),
        overall == 0 ? 0 : value.amountInMinor / overall,
        categoryColor(value.category),
        categoryIcon(value.category),
      );
    }).toList();
    summaries.sort((a, b) => b.progress.compareTo(a.progress));
    return summaries;
  }

  static _DateRange _rangeFor(StatisticsPeriod period, DateTime referenceDate) {
    final today = _startOfDay(referenceDate);
    return switch (period) {
      StatisticsPeriod.oneMonth => _DateRange(
        DateTime(today.year, today.month),
        DateTime(today.year, today.month + 1),
      ),
      StatisticsPeriod.threeMonths => _DateRange(
        DateTime(today.year, today.month - 2),
        DateTime(today.year, today.month + 1),
      ),
      StatisticsPeriod.sixMonths => _DateRange(
        DateTime(today.year, today.month - 5),
        DateTime(today.year, today.month + 1),
      ),
      StatisticsPeriod.oneYear => _DateRange(
        DateTime(today.year, today.month - 11),
        DateTime(today.year, today.month + 1),
      ),
    };
  }

  static int _sumBetween(
    List<TransactionEntity> transactions,
    DateTime start,
    DateTime end,
  ) => transactions
      .where((item) => !item.date.isBefore(start) && item.date.isBefore(end))
      .fold<int>(0, (sum, item) => sum + item.amountInMinor);

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _monthLabel(int month) => const [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ][month - 1];
}

String formatTry(int amountInMinor) => NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
).format(amountInMinor / 100);

String categoryName(TransactionCategory category) => switch (category) {
  TransactionCategory.market => 'Market',
  TransactionCategory.ulasim => 'Ulaşım',
  TransactionCategory.fatura => 'Fatura',
  TransactionCategory.eglence => 'Eğlence',
  TransactionCategory.saglik => 'Sağlık',
  TransactionCategory.giyim => 'Giyim',
  TransactionCategory.diger => 'Diğer',
};

Color categoryColor(TransactionCategory category) => switch (category) {
  TransactionCategory.market => const Color(0xFF10B981),
  TransactionCategory.ulasim => const Color(0xFF3B82F6),
  TransactionCategory.fatura => const Color(0xFFEF4444),
  TransactionCategory.eglence => const Color(0xFF8B5CF6),
  TransactionCategory.saglik => const Color(0xFF06B6D4),
  TransactionCategory.giyim => const Color(0xFFF59E0B),
  TransactionCategory.diger => const Color(0xFF6B7280),
};

IconData categoryIcon(TransactionCategory category) => switch (category) {
  TransactionCategory.market => Icons.shopping_basket_outlined,
  TransactionCategory.ulasim => Icons.directions_bus_outlined,
  TransactionCategory.fatura => Icons.receipt_long_outlined,
  TransactionCategory.eglence => Icons.movie_outlined,
  TransactionCategory.saglik => Icons.health_and_safety_outlined,
  TransactionCategory.giyim => Icons.checkroom_outlined,
  TransactionCategory.diger => Icons.category_outlined,
};

class _DateRange {
  const _DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

class _CategoryTotal {
  const _CategoryTotal({required this.amountInMinor, required this.category});

  final int amountInMinor;
  final TransactionCategory category;

  _CategoryTotal add(int value) =>
      _CategoryTotal(amountInMinor: amountInMinor + value, category: category);
}
