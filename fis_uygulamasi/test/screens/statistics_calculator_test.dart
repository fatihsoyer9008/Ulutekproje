import 'package:app_main/src/screens/statistics/statistics_calculator.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final now = DateTime(2026, 8, 15, 14, 30);

  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('weekly period uses seven calendar days with inclusive day start', () {
    final start = DateTime(2026, 8, 9);
    final result = StatisticsCalculator.filterTransactions(
      [
        _transaction(date: start, amount: 100),
        _transaction(
          date: start.subtract(const Duration(microseconds: 1)),
          amount: 200,
        ),
        _transaction(date: DateTime(2026, 8, 15, 23, 59), amount: 300),
        _transaction(date: DateTime(2026, 8, 16), amount: 400),
      ],
      StatisticsPeriod.weekly,
      now,
    );

    expect(result.map((item) => item.amountInMinor), [100, 300]);
  });

  test('monthly period includes this month and excludes adjacent months', () {
    final result = StatisticsCalculator.filterTransactions(
      [
        _transaction(date: DateTime(2026, 8), amount: 100),
        _transaction(date: DateTime(2026, 8, 31, 23, 59), amount: 200),
        _transaction(date: DateTime(2026, 7, 31, 23, 59), amount: 300),
        _transaction(date: DateTime(2026, 9), amount: 400),
      ],
      StatisticsPeriod.monthly,
      now,
    );

    expect(result.map((item) => item.amountInMinor), [100, 200]);
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

  test('weekly spending always returns seven calendar buckets', () {
    final spending = StatisticsCalculator.spendingSeries(
      [_transaction(date: DateTime(2026, 8, 15), amount: 1250)],
      StatisticsPeriod.weekly,
      now,
    );

    expect(spending, hasLength(7));
    expect(spending.last.amountInMinor, 1250);
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
