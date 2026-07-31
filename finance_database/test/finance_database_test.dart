import 'package:flutter_test/flutter_test.dart';
import 'package:finance_database/finance_database.dart';

void main() {
  test('TransactionEntity alanları doğru atanıyor', () {
    final entity = TransactionEntity()
      ..amountInMinor = 1250
      ..category = TransactionCategory.market
      ..date = DateTime(2026, 7, 27)
      ..merchantName = 'Migros'
      ..source = TransactionSource.ocrRegex
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    expect(entity.amountInMinor, 1250);
    expect(entity.category, TransactionCategory.market);
    expect(entity.merchantName, 'Migros');
    expect(entity.source, TransactionSource.ocrRegex);
  });
}
