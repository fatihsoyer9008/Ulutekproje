import 'dart:math' as math;

import 'package:core_ui/core_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/ui_models.dart';
import 'statistics_calculator.dart';

class StatisticsContent extends StatelessWidget {
  const StatisticsContent({
    required this.categories,
    required this.spending,
    required this.period,
    required this.totalIncomeInMinor,
    required this.totalExpenseInMinor,
    required this.onPeriodChanged,
    super.key,
  });

  final List<CategorySummary> categories;
  final List<MonthlySpending> spending;
  final StatisticsPeriod period;
  final int totalIncomeInMinor;
  final int totalExpenseInMinor;
  final ValueChanged<StatisticsPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final net = totalIncomeInMinor - totalExpenseInMinor;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Genel İstatistik',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${period.subtitle} harcama eğilimi',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<StatisticsPeriod>(
                key: const Key('statistics_period_menu'),
                initialValue: period,
                onSelected: onPeriodChanged,
                itemBuilder: (_) => [
                  for (final value in StatisticsPeriod.values)
                    PopupMenuItem(value: value, child: Text(value.label)),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        period.label,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: scheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 16) / 3;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SummaryTile(
                    width: tileWidth,
                    label: 'Gelir',
                    amountInMinor: totalIncomeInMinor,
                    icon: Icons.south_west_rounded,
                    color: AppColors.income,
                  ),
                  const SizedBox(width: 8),
                  SummaryTile(
                    width: tileWidth,
                    label: 'Gider',
                    amountInMinor: totalExpenseInMinor,
                    icon: Icons.north_east_rounded,
                    color: AppColors.expense,
                  ),
                  const SizedBox(width: 8),
                  SummaryTile(
                    width: tileWidth,
                    label: 'Net Durum',
                    amountInMinor: net,
                    icon: Icons.account_balance_wallet_outlined,
                    color: net >= 0 ? AppColors.primary : AppColors.expense,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          StatisticsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dönem Harcaması',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AnimatedAmountText(
                            amountInMinor: totalExpenseInMinor,
                            color: AppColors.primary,
                            fontSize: 23,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        period.label,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 205,
                  child: StatisticsChart(spending: spending),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Kategoriler',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            StatisticsCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    'Henüz kategori verisi bulunmuyor.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            )
          else
            for (final category in categories) ...[
              CategoryTile(category: category),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class StatisticsCard extends StatelessWidget {
  const StatisticsCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x0D16211D),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
  }
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    required this.width,
    required this.label,
    required this.amountInMinor,
    required this.icon,
    required this.color,
    super.key,
  });

  final double width;
  final String label;
  final int amountInMinor;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedAmountText(
            amountInMinor: amountInMinor,
            color: color,
            fontSize: 14,
          ),
        ],
      ),
    ),
  );
}

class AnimatedAmountText extends StatelessWidget {
  const AnimatedAmountText({
    required this.amountInMinor,
    required this.color,
    this.fontSize = 17,
    super.key,
  });

  final int amountInMinor;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: amountInMinor.toDouble()),
    duration: const Duration(milliseconds: 550),
    curve: Curves.easeOutCubic,
    builder: (_, value, _) => Text(
      formatTry(value.round()),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class StatisticsChart extends StatelessWidget {
  const StatisticsChart({required this.spending, super.key});

  final List<MonthlySpending> spending;

  @override
  Widget build(BuildContext context) {
    if (spending.isEmpty) {
      return Center(
        child: Text(
          'Bu dönem için grafik verisi bulunmuyor.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final values = spending
        .map((item) => item.amountInMinor / 100)
        .toList(growable: false);
    final highest = values.fold<double>(0, math.max);
    final maxY = highest <= 0 ? 10.0 : highest * 1.2;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, spending.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
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
              reservedSize: 34,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= spending.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 10,
                  child: Text(
                    spending[index].label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.inverseSurface,
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    formatTry((spot.y * 100).round()),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < values.length; index++)
                FlSpot(index.toDouble(), values[index]),
            ],
            isCurved: true,
            curveSmoothness: .25,
            color: AppColors.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: Theme.of(context).colorScheme.surface,
                strokeWidth: 3,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: .2),
                  AppColors.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({required this.category, super.key});

  final CategorySummary category;

  @override
  Widget build(BuildContext context) => StatisticsCard(
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: category.color.withValues(alpha: .12),
          child: Icon(category.icon, color: category.color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    category.amount,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '%${(category.progress * 100).round()}',
                      style: TextStyle(
                        color: category.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: category.progress.clamp(0, 1),
                  minHeight: 7,
                  color: category.color,
                  backgroundColor: category.color.withValues(alpha: .12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
