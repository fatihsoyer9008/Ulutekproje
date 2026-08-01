import 'package:core_ui/core_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/ui_models.dart';
import 'statistics_time_filter_service.dart';

class StatisticsChartCard extends StatelessWidget {
  const StatisticsChartCard({
    super.key,
    required this.filter,
    required this.totalExpenseInMinor,
    required this.spendingData,
  });

  final TimeFilter filter;
  final int totalExpenseInMinor;
  final List<MonthlySpending> spendingData;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dönem Toplam Harcaması',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Modern Soft Filter Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatTry(totalExpenseInMinor),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (spendingData.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('Henüz harcama verisi bulunmuyor.')),
            )
          else
            SizedBox(height: 200, child: StatisticsChart(data: spendingData)),
        ],
      ),
    ),
  );
}

class StatisticsChart extends StatelessWidget {
  const StatisticsChart({super.key, required this.data});

  final List<MonthlySpending> data;

  @override
  Widget build(BuildContext context) {
    final max = data.fold<double>(
      0,
      (value, item) =>
          item.amountInMinor / 100 > value ? item.amountInMinor / 100 : value,
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: max == 0 ? 1 : max * 1.15,
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            getTooltipItems: (spots) => spots.map((spot) {
              final item = data[spot.x.toInt()];
              return LineTooltipItem(
                '${item.label}\n${formatTry(item.amountInMinor)}',
                const TextStyle(color: Colors.white),
              );
            }).toList(),
          ),
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
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                return index >= 0 && index < data.length
                    ? SideTitleWidget(
                        meta: meta,
                        child: Text(
                          data[index].label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (index, item) in data.indexed)
                FlSpot(index.toDouble(), item.amountInMinor / 100),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: .15),
            ),
          ),
        ],
      ),
    );
  }
}
