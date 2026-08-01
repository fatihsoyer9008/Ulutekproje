import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import 'statistics_time_filter_service.dart';

void showStatisticsInsightSheet(
  BuildContext context,
  List<TransactionEntity> transactions,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatisticsInsightSheet(transactions: transactions),
  );
}

class StatisticsInsightSheet extends StatelessWidget {
  const StatisticsInsightSheet({super.key, required this.transactions});

  final List<TransactionEntity> transactions;

  String get _insight {
    if (transactions.isEmpty) {
      return 'Bu dönem için analiz oluşturabilecek işlem bulunmuyor.';
    }

    final expenses = transactions
        .where((item) => item.transactionType == TransactionType.expense)
        .toList();

    final income = transactions
        .where((item) => item.transactionType == TransactionType.income)
        .fold<int>(0, (sum, item) => sum + item.amountInMinor);

    final expense = expenses.fold<int>(
      0,
      (sum, item) => sum + item.amountInMinor,
    );

    if (expenses.isEmpty) {
      return 'Bu dönemde ${transactions.length} işlem kaydedildi; gider kaydı olmadığı için harcama eğilimi oluşmadı.';
    }

    final totals = <String, int>{};
    for (final item in expenses) {
      final name = categoryDisplayName(item);
      totals.update(
        name,
        (value) => value + item.amountInMinor,
        ifAbsent: () => item.amountInMinor,
      );
    }

    final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final ratio = (top.value / expense * 100).round();

    final balance = income == 0
        ? 'Gelir kaydı olmadığı için denge hesaplanamadı.'
        : expense > income
        ? 'Giderler gelirlerden yüksek; harcamaları gözden geçirmek faydalı olabilir.'
        : 'Gelir-gider dengesi olumlu görünüyor.';

    return 'Bu dönemde ${transactions.length} işlem kaydedildi. En yüksek harcama ${top.key} kategorisinde ve giderlerin %$ratio\'ini oluşturuyor. $balance';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Akıllı Harcama Özeti',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          _insight,
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım'),
          ),
        ),
      ],
    ),
  );
}
