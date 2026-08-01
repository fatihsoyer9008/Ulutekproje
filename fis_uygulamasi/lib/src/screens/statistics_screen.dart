import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import '../models/ui_models.dart';
import 'statistics/statistics_calculator.dart';
import 'statistics/statistics_insight_sheet.dart';
import 'statistics/statistics_widgets.dart';

export 'statistics/statistics_calculator.dart' show StatisticsPeriod;

class StatisticsScreenController {
  VoidCallback? _showSummary;

  void showSummary() => _showSummary?.call();
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    this.controller,
    this.categories = const [],
    this.monthlySpending = const [],
    this.transactions,
    this.referenceDate,
    this.initialPeriod = StatisticsPeriod.sixMonths,
  });

  final StatisticsScreenController? controller;

  /// Legacy presentation input retained for callers that do not provide
  /// transaction records. New application code should pass [transactions].
  final List<CategorySummary> categories;
  final List<MonthlySpending> monthlySpending;
  final List<TransactionEntity>? transactions;

  /// Makes period boundaries deterministic in tests.
  final DateTime? referenceDate;
  final StatisticsPeriod initialPeriod;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late StatisticsPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    widget.controller?._showSummary = _showSummary;
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._showSummary = null;
      widget.controller?._showSummary = _showSummary;
    }
  }

  @override
  void dispose() {
    widget.controller?._showSummary = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = StatisticsCalculator.calculate(
      transactions: widget.transactions ?? const [],
      period: _period,
      referenceDate: widget.referenceDate,
    );
    final usesLegacyData = widget.transactions == null;
    final categories = usesLegacyData ? widget.categories : snapshot.categories;
    final spending = usesLegacyData
        ? widget.monthlySpending
        : snapshot.spending;
    final legacyExpense = widget.monthlySpending.fold<int>(
      0,
      (sum, item) => sum + item.amountInMinor,
    );

    return Scaffold(
      body: StatisticsContent(
        categories: categories,
        spending: spending,
        period: _period,
        totalIncomeInMinor: usesLegacyData ? 0 : snapshot.totalIncomeInMinor,
        totalExpenseInMinor: usesLegacyData
            ? legacyExpense
            : snapshot.totalExpenseInMinor,
        onPeriodChanged: (value) => setState(() => _period = value),
      ),
    );
  }

  void _showSummary() {
    if (!mounted) return;
    final snapshot = StatisticsCalculator.calculate(
      transactions: widget.transactions ?? const [],
      period: _period,
      referenceDate: widget.referenceDate,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          StatisticsInsightSheet(snapshot: snapshot, period: _period),
    );
  }
}
