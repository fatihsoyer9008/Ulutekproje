import 'package:app_main/src/screens/statistics_time_filter_service.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 1, 15);
  final service = StatisticsTimeFilterService(now: () => now);

  test('weekly filter starts at the first calendar day, not 168 hours ago', () {
    final result = service.filter([
      _transaction(DateTime(2026, 7, 26, 0)),
      _transaction(DateTime(2026, 7, 25, 23, 59)),
    ], TimeFilter.weekly);
    expect(result, hasLength(1));
    expect(result.single.date, DateTime(2026, 7, 26));
  });

  test('monthly filter includes only the current calendar month', () {
    final result = service.filter([
      _transaction(DateTime(2026, 8, 1)),
      _transaction(DateTime(2026, 8, 31, 23, 59)),
      _transaction(DateTime(2026, 7, 31, 23, 59)),
    ], TimeFilter.monthly);
    expect(result, hasLength(2));
  });

  test('six-month filter includes its first day at midnight', () {
    final result = service.filter([
      _transaction(DateTime(2026, 3, 1)),
      _transaction(DateTime(2026, 2, 28, 23, 59)),
    ], TimeFilter.sixMonths);
    expect(result, hasLength(1));
    expect(result.single.date, DateTime(2026, 3, 1));
  });

  test('category summaries retain user supplied category names', () {
    final summary = categorySummaries([_transaction(DateTime(2026, 8, 1), categoryName: 'Evcil Hayvan')]);
    expect(summary.single.name, 'Evcil Hayvan');
  });
}

TransactionEntity _transaction(DateTime date, {String? categoryName}) => TransactionEntity()
  ..transactionType = TransactionType.expense
  ..amountInMinor = 100
  ..category = TransactionCategory.diger
  ..categoryName = categoryName
  ..date = date
  ..merchantName = 'Test'
  ..source = TransactionSource.manual
  ..createdAt = date
  ..updatedAt = date;
