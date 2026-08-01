import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ui_models.dart';

enum TimeFilter {
  weekly('Haftalık', 'Son 7 takvim günündeki harcama eğilimi'),
  monthly('Aylık', 'Bu ayki harcama eğilimi'),
  sixMonths('6 Ay', 'Son 6 aydaki harcama eğilimi');

  const TimeFilter(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

/// Produces a consistent calendar-based statistics period.
class StatisticsTimeFilterService {
  const StatisticsTimeFilterService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  List<TransactionEntity> filter(
    List<TransactionEntity> transactions,
    TimeFilter filter,
  ) {
    final now = _now();
    late final DateTime start;
    late final DateTime end;

    switch (filter) {
      case TimeFilter.weekly:
        // Bugün dahil son 7 takvim gününün ilk günü (00:00:00)
        start = DateTime(now.year, now.month, now.day - 6);
        // Yarının ilk günü (00:00:00) - Excluded
        end = DateTime(now.year, now.month, now.day + 1);
        break;

      case TimeFilter.monthly:
        // Mevcut ayın 1. günü (00:00:00)
        start = DateTime(now.year, now.month, 1);
        // Gelecek ayın 1. günü (00:00:00) - Excluded
        end = DateTime(now.year, now.month + 1, 1);
        break;

      case TimeFilter.sixMonths:
        // 5 ay öncesinin 1. günü (00:00:00) - Inclusive
        start = DateTime(now.year, now.month - 5, 1);
        // Gelecek ayın 1. günü (00:00:00) - Excluded
        end = DateTime(now.year, now.month + 1, 1);
        break;
    }

    return transactions.where((transaction) {
      final date = transaction.date;
      return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
          date.isBefore(end);
    }).toList();
  }

  List<MonthlySpending> spendingData(
    List<TransactionEntity> transactions,
    TimeFilter filter,
  ) {
    final now = _now();
    return switch (filter) {
      TimeFilter.weekly => List.generate(7, (index) {
        final day = DateTime(now.year, now.month, now.day - 6 + index);
        return MonthlySpending(
          DateFormat.E('tr_TR').format(day),
          _totalForDay(transactions, day),
        );
      }),
      TimeFilter.monthly => List.generate(4, (index) {
        final startDay = index * 7 + 1;
        final endDay = index == 3 ? 31 : (index + 1) * 7;
        final total = transactions
            .where(
              (item) =>
                  item.date.year == now.year &&
                  item.date.month == now.month &&
                  item.date.day >= startDay &&
                  item.date.day <= endDay,
            )
            .fold<int>(0, (sum, item) => sum + item.amountInMinor);
        return MonthlySpending('${index + 1}. Hafta', total);
      }),
      TimeFilter.sixMonths => List.generate(6, (index) {
        final month = DateTime(now.year, now.month - 5 + index, 1);
        final total = transactions
            .where(
              (item) =>
                  item.date.year == month.year &&
                  item.date.month == month.month,
            )
            .fold<int>(0, (sum, item) => sum + item.amountInMinor);
        return MonthlySpending(DateFormat.MMM('tr_TR').format(month), total);
      }),
    };
  }

  int _totalForDay(List<TransactionEntity> transactions, DateTime day) =>
      transactions
          .where(
            (item) =>
                item.date.year == day.year &&
                item.date.month == day.month &&
                item.date.day == day.day,
          )
          .fold<int>(0, (sum, item) => sum + item.amountInMinor);
}

List<CategorySummary> categorySummaries(List<TransactionEntity> transactions) {
  if (transactions.isEmpty) return const [];
  final totals = <String, int>{};
  final types = <String, TransactionCategory>{};
  for (final item in transactions) {
    final name = categoryDisplayName(item);
    totals.update(
      name,
      (value) => value + item.amountInMinor,
      ifAbsent: () => item.amountInMinor,
    );
    types.putIfAbsent(name, () => item.category);
  }
  final overall = totals.values.fold<int>(0, (sum, item) => sum + item);
  final result =
      totals.entries
          .map(
            (entry) => CategorySummary(
              entry.key,
              formatTry(entry.value),
              overall == 0 ? 0 : entry.value / overall,
              categoryColor(types[entry.key]!),
              categoryIcon(types[entry.key]!),
            ),
          )
          .toList()
        ..sort((a, b) => b.progress.compareTo(a.progress));
  return result;
}

String categoryDisplayName(TransactionEntity transaction) =>
    transaction.categoryName?.trim().isNotEmpty == true
    ? transaction.categoryName!.trim()
    : categoryName(transaction.category);

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
