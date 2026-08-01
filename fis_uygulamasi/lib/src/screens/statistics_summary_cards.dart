import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/ui_models.dart';
import 'statistics_time_filter_service.dart';

class StatisticsSummaryCards extends StatelessWidget {
  const StatisticsSummaryCards({
    super.key,
    required this.incomeInMinor,
    required this.expenseInMinor,
  });

  final int incomeInMinor;
  final int expenseInMinor;

  @override
  Widget build(BuildContext context) {
    final balance = incomeInMinor - expenseInMinor;
    return Row(
      children: [
        Expanded(
          child: _Card(
            title: 'Gelir',
            amount: incomeInMinor,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Card(
            title: 'Gider',
            amount: expenseInMinor,
            color: const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Card(
            title: 'Net Durum',
            amount: balance,
            color: balance >= 0 ? AppColors.primary : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.amount, required this.color});

  final String title;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            formatTry(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

class StatisticsCategoryList extends StatelessWidget {
  const StatisticsCategoryList({super.key, required this.categories});

  final List<CategorySummary> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const _EmptyCategories();
    return Column(
      children: categories
          .map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryTile(category: category),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Center(child: Text('Henüz kategori verisi bulunmuyor.')),
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategorySummary category;

  @override
  Widget build(BuildContext context) {
    final percentage = (category.progress * 100).round();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  category.amount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                // Modern Soft Percent Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '%$percentage',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: category.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: category.progress,
                color: category.color,
                backgroundColor: category.color.withValues(alpha: 0.12),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
