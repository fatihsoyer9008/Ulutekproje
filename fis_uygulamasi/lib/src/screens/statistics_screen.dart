import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import '../models/ui_models.dart';
import 'statistics_chart.dart';
import 'statistics_insight_sheet.dart';
import 'statistics_summary_cards.dart';
import 'statistics_time_filter_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    this.categories = const [],
    this.monthlySpending = const [],
    this.transactions,
    this.filterService = const StatisticsTimeFilterService(),
  });

  /// Legacy inputs remain supported for callers that do not provide transactions.
  final List<CategorySummary> categories;
  final List<MonthlySpending> monthlySpending;
  final List<TransactionEntity>? transactions;
  final StatisticsTimeFilterService filterService;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  TimeFilter _selectedFilter = TimeFilter.sixMonths;

  @override
  Widget build(BuildContext context) {
    final transactions = widget.transactions;
    final filtered = transactions == null
        ? const <TransactionEntity>[]
        : widget.filterService.filter(transactions, _selectedFilter);
    final expenses = filtered
        .where((item) => item.transactionType == TransactionType.expense)
        .toList();

    // Legacy veriler ile çağrıldığında toplam gider harcama listesinden hesaplanır
    final totalExpense = transactions == null
        ? widget.monthlySpending.fold<int>(
            0,
            (sum, item) => sum + item.amountInMinor,
          )
        : expenses.fold<int>(0, (sum, item) => sum + item.amountInMinor);

    final totalIncome = filtered
        .where((item) => item.transactionType == TransactionType.income)
        .fold<int>(0, (sum, item) => sum + item.amountInMinor);

    return Scaffold(
      floatingActionButton: _InsightButton(
        onPressed: () => showStatisticsInsightSheet(context, filtered),
      ),
      body: _StatisticsContent(
        categories: transactions == null
            ? widget.categories
            : categorySummaries(expenses),
        spendingData: transactions == null
            ? widget.monthlySpending
            : widget.filterService.spendingData(expenses, _selectedFilter),
        selectedFilter: _selectedFilter,
        totalExpenseInMinor: totalExpense,
        totalIncomeInMinor: totalIncome,
        onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({
    required this.categories,
    required this.spendingData,
    required this.selectedFilter,
    required this.totalExpenseInMinor,
    required this.totalIncomeInMinor,
    required this.onFilterChanged,
  });

  final List<CategorySummary> categories;
  final List<MonthlySpending> spendingData;
  final TimeFilter selectedFilter;
  final int totalExpenseInMinor;
  final int totalIncomeInMinor;
  final ValueChanged<TimeFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Genel İstatistik',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                selectedFilter.subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
          PopupMenuButton<TimeFilter>(
            initialValue: selectedFilter,
            onSelected: onFilterChanged,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedFilter.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            itemBuilder: (_) => TimeFilter.values
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
      StatisticsSummaryCards(
        incomeInMinor: totalIncomeInMinor,
        expenseInMinor: totalExpenseInMinor,
      ),
      const SizedBox(height: 16),
      StatisticsChartCard(
        filter: selectedFilter,
        totalExpenseInMinor: totalExpenseInMinor,
        spendingData: spendingData,
      ),
      const SizedBox(height: 28),
      Text(
        'Kategoriler',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      StatisticsCategoryList(categories: categories),
    ],
  );
}

class _InsightButton extends StatelessWidget {
  const _InsightButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    onPressed: onPressed,
    backgroundColor: AppColors.primary,
    icon: const Icon(Icons.auto_awesome, color: Colors.white),
    label: const Text(
      'Akıllı Özet',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}
