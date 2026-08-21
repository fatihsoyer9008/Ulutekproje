import 'package:app_main/src/screens/statistics/statistics_calculator.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final now = DateTime(2026, 8, 15, 14, 30);

  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('one month period includes this month and excludes adjacent months', () {
    final result = StatisticsCalculator.filterTransactions(
      [
        _transaction(date: DateTime(2026, 8), amount: 100),
        _transaction(date: DateTime(2026, 8, 31, 23, 59), amount: 200),
        _transaction(date: DateTime(2026, 7, 31, 23, 59), amount: 300),
        _transaction(date: DateTime(2026, 9), amount: 400),
      ],
      StatisticsPeriod.oneMonth,
      now,
    );

    expect(result.map((item) => item.amountInMinor), [100, 200]);
  });

  test('three month period starts at the first day three months wide', () {
    final result = StatisticsCalculator.filterTransactions(
      [
        _transaction(date: DateTime(2026, 6), amount: 100),
        _transaction(date: DateTime(2026, 5, 31, 23, 59), amount: 200),
        _transaction(date: DateTime(2026, 8, 31, 23, 59), amount: 300),
      ],
      StatisticsPeriod.threeMonths,
      now,
    );

    expect(result.map((item) => item.amountInMinor), [100, 300]);
  });

  test('six month period includes first month midnight', () {
    final start = DateTime(2026, 3);
    final result = StatisticsCalculator.filterTransactions(
      [
        _transaction(date: start, amount: 100),
        _transaction(
          date: start.subtract(const Duration(microseconds: 1)),
          amount: 200,
        ),
        _transaction(date: DateTime(2026, 8, 31, 23, 59), amount: 300),
      ],
      StatisticsPeriod.sixMonths,
      now,
    );

    expect(result.map((item) => item.amountInMinor), [100, 300]);
  });

  test('category summaries preserve custom category names separately', () {
    final summaries = StatisticsCalculator.categorySummaries([
      _transaction(
        date: now,
        amount: 1000,
        category: TransactionCategory.diger,
        categoryName: 'Evcil Hayvan',
      ),
      _transaction(
        date: now,
        amount: 500,
        category: TransactionCategory.diger,
        categoryName: 'Hobi',
      ),
      _transaction(
        date: now,
        amount: 250,
        category: TransactionCategory.market,
      ),
    ]);

    expect(summaries.map((item) => item.name), [
      'Evcil Hayvan',
      'Hobi',
      'Market',
    ]);
    expect(summaries.first.progress, closeTo(1000 / 1750, .0001));
  });

  test('one month spending returns calendar week buckets', () {
    final spending = StatisticsCalculator.spendingSeries(
      [_transaction(date: DateTime(2026, 8, 15), amount: 1250)],
      StatisticsPeriod.oneMonth,
      now,
    );

    expect(spending, hasLength(5));
    expect(spending[2].amountInMinor, 1250);
  });

  test('one year period returns twelve monthly buckets', () {
    final spending = StatisticsCalculator.spendingSeries(
      [_transaction(date: DateTime(2025, 9, 1), amount: 1250)],
      StatisticsPeriod.oneYear,
      now,
    );

    expect(spending, hasLength(12));
    expect(spending.first.label, 'Eyl');
    expect(spending.first.amountInMinor, 1250);
    expect(spending.last.label, 'Ağu');
  });
}

TransactionEntity _transaction({
  required DateTime date,
  required int amount,
  TransactionCategory category = TransactionCategory.market,
  String? categoryName,
  TransactionType type = TransactionType.expense,
}) => TransactionEntity()
  ..amountInMinor = amount
  ..category = category
  ..categoryName = categoryName
  ..date = date
  ..source = TransactionSource.manual
  ..transactionType = type
  ..createdAt = date
  ..updatedAt = date;
