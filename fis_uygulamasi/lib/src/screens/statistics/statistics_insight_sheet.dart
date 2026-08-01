import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'statistics_calculator.dart';

class StatisticsInsightSheet extends StatelessWidget {
  const StatisticsInsightSheet({
    required this.snapshot,
    required this.period,
    super.key,
  });

  final StatisticsSnapshot snapshot;
  final StatisticsPeriod period;

  @override
  Widget build(BuildContext context) {
    final insight = buildStatisticsInsight(snapshot, period);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.mint,
                  child: Icon(
                    Icons.insights_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Akıllı Harcama Özeti',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              insight,
              key: const Key('statistics_insight_text'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String buildStatisticsInsight(
  StatisticsSnapshot snapshot,
  StatisticsPeriod period,
) {
  if (snapshot.transactions.isEmpty) {
    return '${period.label} dönem için henüz analiz edilebilecek işlem bulunmuyor.';
  }
  if (snapshot.totalExpenseInMinor == 0) {
    return '${period.label} dönemde gider kaydı bulunmuyor. '
        'Toplam gelirin ${formatTry(snapshot.totalIncomeInMinor)}.';
  }

  final topCategory = snapshot.categories.first;
  final percentage = (topCategory.progress * 100).round();
  final balanceText = snapshot.netBalanceInMinor >= 0
      ? 'Dönem sonunda ${formatTry(snapshot.netBalanceInMinor)} artıdasın.'
      : 'Giderlerin gelirlerini ${formatTry(-snapshot.netBalanceInMinor)} aştı.';

  return '${period.label} dönemde en yüksek harcama kategorin '
      '${topCategory.name} (%$percentage). $balanceText';
}
