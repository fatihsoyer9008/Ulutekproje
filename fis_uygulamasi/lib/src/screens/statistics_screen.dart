import 'package:core_ui/core_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/ui_models.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({
    super.key,
    this.categories = const [],
    this.monthlySpending = const [],
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

class _Chart extends StatelessWidget {
  const _Chart({required this.monthlySpending});

  final List<MonthlySpending> monthlySpending;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final (index, spending) in monthlySpending.indexed)
        FlSpot(index.toDouble(), spending.amount),
    ];
    final highestAmount = monthlySpending.fold<double>(
      0,
      (highest, spending) =>
          spending.amount > highest ? spending.amount : highest,
    );

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
