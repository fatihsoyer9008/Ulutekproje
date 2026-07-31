import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ui_models.dart';

enum TimeFilter {
  weekly('Haftalık', 'Son 7 günlük harcama eğilimi'),
  monthly('Aylık', 'Bu ayki harcama eğilimi'),
  sixMonths('6 Ay', 'Son 6 aylık harcama eğilimi');

  const TimeFilter(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    this.categories = const [],
    this.monthlySpending = const [],
    this.transactions,
  });

  final List<CategorySummary> categories;
  final List<MonthlySpending> monthlySpending;
  final List<TransactionEntity>? transactions;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  TimeFilter _selectedFilter = TimeFilter.sixMonths;

  @override
  Widget build(BuildContext context) {
    final currentTransactions = widget.transactions ?? [];

    final filteredTransactions =
        _filterTransactionsByTime(currentTransactions, _selectedFilter);

    final totalExpense = filteredTransactions
        .where((t) => t.transactionType == TransactionType.expense)
        .fold<int>(0, (sum, t) => sum + t.amountInMinor);

    final totalIncome = filteredTransactions
        .where((t) => t.transactionType == TransactionType.income)
        .fold<int>(0, (sum, t) => sum + t.amountInMinor);

    final expensesOnly = filteredTransactions
        .where((t) => t.transactionType == TransactionType.expense)
        .toList();

    return Scaffold(
      floatingActionButton: _AiAssistantFab(
        onPressed: () => _showAiInsightsSheet(context, filteredTransactions),
      ),
      body: _StatisticsContent(
        categories: _categorySummaries(expensesOnly),
        spendingData: _calculateSpendingData(expensesOnly, _selectedFilter),
        selectedFilter: _selectedFilter,
        onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
        totalExpenseInMinor: totalExpense,
        totalIncomeInMinor: totalIncome,
      ),
    );
  }

  void _showAiInsightsSheet(
      BuildContext context, List<TransactionEntity> transactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AiInsightBottomSheet(transactions: transactions),
    );
  }

  List<TransactionEntity> _filterTransactionsByTime(
    List<TransactionEntity> transactions,
    TimeFilter filter,
  ) {
    final now = DateTime.now();
    return transactions.where((t) {
      switch (filter) {
        case TimeFilter.weekly:
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          return t.date.isAfter(sevenDaysAgo);
        case TimeFilter.monthly:
          return t.date.year == now.year && t.date.month == now.month;
        case TimeFilter.sixMonths:
          final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
          return t.date.isAfter(sixMonthsAgo);
      }
    }).toList();
  }

  List<MonthlySpending> _calculateSpendingData(
    List<TransactionEntity> transactions,
    TimeFilter filter,
  ) {
    if (transactions.isEmpty) return const [];
    final now = DateTime.now();

    switch (filter) {
      case TimeFilter.weekly:
        return List.generate(7, (i) {
          final day = now.subtract(Duration(days: 6 - i));
          final total = transactions
              .where((t) =>
                  t.date.year == day.year &&
                  t.date.month == day.month &&
                  t.date.day == day.day)
              .fold<int>(0, (sum, t) => sum + t.amountInMinor);
          return MonthlySpending(DateFormat.E('tr_TR').format(day), total);
        });

      case TimeFilter.monthly:
        return List.generate(4, (i) {
          final startDay = (i * 7) + 1;
          final endDay = (i == 3) ? 31 : (i + 1) * 7;

          final total = transactions
              .where((t) =>
                  t.date.year == now.year &&
                  t.date.month == now.month &&
                  t.date.day >= startDay &&
                  t.date.day <= endDay)
              .fold<int>(0, (sum, t) => sum + t.amountInMinor);

          return MonthlySpending('${i + 1}. Hafta', total);
        });

      case TimeFilter.sixMonths:
        return List.generate(6, (i) {
          final monthOffset = 5 - i;
          final targetMonth = DateTime(now.year, now.month - monthOffset);
          final total = transactions
              .where((t) =>
                  t.date.year == targetMonth.year &&
                  t.date.month == targetMonth.month)
              .fold<int>(0, (sum, t) => sum + t.amountInMinor);
          return MonthlySpending(
            DateFormat.MMM('tr_TR').format(targetMonth),
            total,
          );
        });
    }
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({
    required this.categories,
    required this.spendingData,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.totalExpenseInMinor,
    required this.totalIncomeInMinor,
  });

  final List<CategorySummary> categories;
  final List<MonthlySpending> spendingData;
  final TimeFilter selectedFilter;
  final ValueChanged<TimeFilter> onFilterChanged;
  final int totalExpenseInMinor;
  final int totalIncomeInMinor;

  @override
  Widget build(BuildContext context) {
    final netBalanceInMinor = totalIncomeInMinor - totalExpenseInMinor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        // 1. Diğer sekmelerle tam uyumlu Header yapısı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Genel İstatistik',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  selectedFilter.subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            PopupMenuButton<TimeFilter>(
              initialValue: selectedFilter,
              onSelected: onFilterChanged,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedFilter.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              itemBuilder: (context) => TimeFilter.values
                  .map(
                    (filter) => PopupMenuItem(
                      value: filter,
                      child: Text(
                        filter.label,
                        style: TextStyle(
                          fontWeight: filter == selectedFilter
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: filter == selectedFilter
                              ? AppColors.primary
                              : null,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Özet Kartları
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                title: 'Gelir',
                amountInMinor: totalIncomeInMinor,
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                title: 'Gider',
                amountInMinor: totalExpenseInMinor,
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                title: 'Net Durum',
                amountInMinor: netBalanceInMinor,
                icon: Icons.account_balance_wallet_outlined,
                color: netBalanceInMinor >= 0
                    ? AppColors.primary
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Ana Grafik Kartı
        _ModernCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dönem Harcaması',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      selectedFilter.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // ₺2.000,00 yazısının rengi eski haline (Yeşil) döndürüldü
              _AnimatedAmountText(
                amountInMinor: totalExpenseInMinor,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 39, 114, 60),
                    ),
              ),
              const SizedBox(height: 20),
              if (spendingData.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Text('Henüz harcama verisi bulunmuyor.'),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: _Chart(monthlySpending: spendingData),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 4. Kategori Listesi
        Text(
          'Kategoriler',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          const _ModernCard(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('Henüz kategori verisi bulunmuyor.')),
          ),
        ...categories.map(
          (category) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategoryTile(category: category),
          ),
        ),
      ],
    );
  }
}

class _ModernCard extends StatelessWidget {
  const _ModernCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.amountInMinor,
    required this.icon,
    required this.color,
  });

  final String title;
  final int amountInMinor;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AnimatedAmountText(
            amountInMinor: amountInMinor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedAmountText extends StatelessWidget {
  const _AnimatedAmountText({
    required this.amountInMinor,
    this.style,
  });

  final int amountInMinor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final targetValue = amountInMinor / 100;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetValue),
      duration: const Duration(milliseconds: 750),
      curve: Curves.fastOutSlowIn,
      builder: (context, value, child) {
        final formatted = NumberFormat.currency(
          locale: 'tr_TR',
          symbol: '₺',
          decimalDigits: 2,
        ).format(value);

        return Text(formatted, style: style);
      },
    );
  }
}

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

    final maxSpotX = spots.isEmpty ? 1.0 : (spots.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: highestAmount == 0 ? 1 : highestAmount * 1.15,
        minX: 0,
        maxX: maxSpotX,
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((spotIndex) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  strokeWidth: 1.5,
                  dashArray: [4, 4],
                ),
                FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: AppColors.primary,
                      strokeWidth: 3,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            // Tooltip arka plan rengi AppColors.primary yapıldı
            getTooltipColor: (touchedSpot) => AppColors.primary,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= monthlySpending.length) {
                  return null;
                }
                final item = monthlySpending[index];
                final formattedAmount = NumberFormat.currency(
                  locale: 'tr_TR',
                  symbol: '₺',
                  decimalDigits: 2,
                ).format(item.amountInMinor / 100);

                return LineTooltipItem(
                  '${item.label}\n$formattedAmount',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
        // Çok silik ve ince kesikli kılavuz çizgileri geri eklendi
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval:
              (highestAmount == 0 ? 1 : highestAmount * 1.15) / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.primary.withValues(alpha: 0.08),
            strokeWidth: 1,
            dashArray: const [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (value != index.toDouble() ||
                    index < 0 ||
                    index >= monthlySpending.length) {
                  return const SizedBox.shrink();
                }

                Widget textWidget = Text(
                  monthlySpending[index].label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                );

                if (index == 0) {
                  textWidget = Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: textWidget,
                  );
                } else if (index == monthlySpending.length - 1) {
                  textWidget = Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: textWidget,
                  );
                }

                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: textWidget,
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            color: AppColors.primary,
            barWidth: 3.5,
            isStrokeCapRound: true,
            // X ekseni noktaları üzerindeki yuvarlak daireler geri eklendi
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: AppColors.primary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: .28),
                  AppColors.primary.withValues(alpha: .0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategorySummary category;

  @override
  Widget build(BuildContext context) {
    final percentage = (category.progress * 100).toStringAsFixed(0);

    return _ModernCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: category.color.withValues(alpha: .12),
            child: Icon(category.icon, color: category.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          category.amount,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: category.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(6),
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
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: category.progress,
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
}

class _AiAssistantFab extends StatelessWidget {
  const _AiAssistantFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        label: const Text(
          'AI Asistan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _AiInsightBottomSheet extends StatelessWidget {
  const _AiInsightBottomSheet({required this.transactions});

  final List<TransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Harcama Analizi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Bu ayki harcama alışkanlıklarına göre en çok harcaman Market kategorisinde gerçekleşti. Geçen haftaya kıyasla %12 tasarruf potansiyeli tespit edildi.',
            style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Anladım',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      TransactionCategory.market => const Color(0xFF10B981),
      TransactionCategory.ulasim => const Color(0xFF3B82F6),
      TransactionCategory.fatura => const Color(0xFFEF4444),
      TransactionCategory.eglence => const Color(0xFF8B5CF6),
      TransactionCategory.saglik => const Color(0xFF06B6D4),
      TransactionCategory.giyim => const Color(0xFFF59E0B),
      TransactionCategory.diger => const Color(0xFF6B7280),
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