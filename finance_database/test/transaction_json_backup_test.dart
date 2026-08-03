import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  group('TransactionJsonBackup', () {
    test('versioned JSON yedeğindeki tüm işlem alanlarını çözümler', () {
      final transactions = TransactionJsonBackup.decode('''
{
  "schemaVersion": 1,
  "exportedAt": "2026-07-30T10:00:00.000Z",
  "transactions": [
    {
      "id": 42,
      "transactionType": "expense",
      "amountInMinor": 12550,
      "category": "market",
      "date": "2026-07-29T18:30:00.000Z",
      "merchantName": "Migros",
      "source": "ocrLlm",
      "rawOcrText": "TOPLAM 125,50",
      "note": "Haftalık alışveriş",
      "createdAt": "2026-07-29T18:31:00.000Z",
      "updatedAt": "2026-07-29T18:32:00.000Z"
    }
  ]
}
''');

      expect(transactions, hasLength(1));
      final transaction = transactions.single;
      expect(transaction.id, Isar.autoIncrement);
      expect(transaction.transactionType, TransactionType.expense);
      expect(transaction.amountInMinor, 12550);
      expect(transaction.category, TransactionCategory.market);
      expect(transaction.date, DateTime.parse('2026-07-29T18:30:00.000Z'));
      expect(transaction.merchantName, 'Migros');
      expect(transaction.source, TransactionSource.ocrLlm);
      expect(transaction.rawOcrText, 'TOPLAM 125,50');
      expect(transaction.note, 'Haftalık alışveriş');
      expect(transaction.createdAt, DateTime.parse('2026-07-29T18:31:00.000Z'));
      expect(transaction.updatedAt, DateTime.parse('2026-07-29T18:32:00.000Z'));
    });

    test('liste kökünü ve snake_case alanlarını destekler', () {
      final transactions = TransactionJsonBackup.decode('''
[
  {
    "transaction_type": "income",
    "amount_in_minor": 500000,
    "category": "diger",
    "date": "2026-07-30T09:00:00",
    "merchant_name": "Maaş",
    "source": "manual",
    "created_at": "2026-07-30T09:00:00",
    "updated_at": "2026-07-30T09:00:00"
  }
]
''');

      expect(transactions.single.transactionType, TransactionType.income);
      expect(transactions.single.amountInMinor, 500000);
      expect(transactions.single.merchantName, 'Maaş');
    });

    test('sürüm 2 JSON yedeğindeki fiş ürünlerini çözümler', () {
      final transactions = TransactionJsonBackup.decode('''
{
  "schemaVersion": 2,
  "transactions": [
    {
      "transactionType": "expense",
      "amountInMinor": 2500,
      "category": "market",
      "date": "2026-08-03T12:00:00Z",
      "source": "ocrLlm",
      "receiptItems": [
        {
          "name": "Süt",
          "quantity": 2,
          "unitPriceInMinor": 1250,
          "totalAmountInMinor": 2500
        }
      ]
    }
  ]
}
''');

      final transaction = transactions.single;
      expect(transaction.receiptLineItemsLoaded, isTrue);
      expect(transaction.receiptLineItems.single.name, 'Süt');
      expect(transaction.receiptLineItems.single.quantity, 2);
      expect(transaction.receiptLineItems.single.totalAmountInMinor, 2500);
    });

    test('geçersiz bir kayıt varsa dosyanın tamamını reddeder', () {
      expect(
        () => TransactionJsonBackup.decode('''
{
  "schemaVersion": 1,
  "transactions": [
    {
      "transactionType": "expense",
      "amountInMinor": 1000,
      "category": "market",
      "date": "2026-07-30T09:00:00",
      "source": "manual"
    },
    {
      "transactionType": "expense",
      "amountInMinor": "10,00",
      "category": "market",
      "date": "2026-07-30T09:00:00",
      "source": "manual"
    }
  ]
}
'''),
        throwsA(
          isA<TransactionJsonImportException>().having(
            (error) => error.message,
            'message',
            contains('2. işlem'),
          ),
        ),
      );
    });

    test('desteklenmeyen yeni şema sürümünü reddeder', () {
      expect(
        () => TransactionJsonBackup.decode(
          '{"schemaVersion": 3, "transactions": []}',
        ),
        throwsA(isA<TransactionJsonImportException>()),
      );
    });
  });
}
