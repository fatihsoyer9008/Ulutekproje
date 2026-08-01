import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dışa aktarılan CSV biçimini işlem listesine dönüştürür', () {
    const source =
        '\uFEFFsep=;\r\n'
        'id;transactionType;amountInMinor;category;date;merchantName;source;rawOcrText;note;createdAt;updatedAt\r\n'
        '1;expense;2500;market;2026-07-30T08:00:00.000;"Market; Kadıköy";manual;;"iki\r\nsatır";2026-07-30T08:00:00.000;2026-07-30T09:00:00.000\r\n';

    final transactions = TransactionCsvBackup.decode(source);

    expect(transactions, hasLength(1));
    final transaction = transactions.single;
    expect(transaction.transactionType, TransactionType.expense);
    expect(transaction.amountInMinor, 2500);
    expect(transaction.category, TransactionCategory.market);
    expect(transaction.merchantName, 'Market; Kadıköy');
    expect(transaction.note, 'iki\r\nsatır');
    expect(transaction.source, TransactionSource.manual);
  });

  test('zorunlu CSV sütunları eksikse anlaşılır hata verir', () {
    const source = 'amountInMinor;category\r\n1000;market\r\n';

    expect(
      () => TransactionCsvBackup.decode(source),
      throwsA(
        isA<TransactionJsonImportException>().having(
          (error) => error.message,
          'message',
          contains('zorunlu alanlar eksik'),
        ),
      ),
    );
  });
}
