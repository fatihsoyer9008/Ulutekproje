import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:app_main/features/transaction_draft/model/turkish_money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Turkish money conversion', () {
    test('parses comma decimal and thousands separators as minor units', () {
      expect(parseTurkishLiraToMinor('1.234,56'), 123456);
      expect(parseTurkishLiraToMinor('12,5'), 1250);
      expect(parseTurkishLiraToMinor('10'), 1000);
    });

    test('rejects malformed or over-precise amounts', () {
      expect(parseTurkishLiraToMinor('12,345'), isNull);
      expect(parseTurkishLiraToMinor('1.23,45'), isNull);
      expect(parseTurkishLiraToMinor('abc'), isNull);
    });

    test('formats minor units for Turkish users', () {
      expect(formatMinorAsTurkishLira(123456), '1.234,56');
    });
  });

  group('TransactionDraft', () {
    test('prefers amountInMinor from API', () {
      final draft = TransactionDraft.fromJson({
        'merchant_name': 'Market',
        'category': 'Gıda',
        'amountInMinor': 123456,
        'amount': 1,
      });

      expect(draft.amountInMinor, 123456);
      expect(draft.toJson()['amountInMinor'], 123456);
    });

    test('converts legacy major amount without floating-point arithmetic', () {
      final draft = TransactionDraft.fromJson({'amount': '1234.56'});
      expect(draft.amountInMinor, 123456);
    });

    test('reads the current FastAPI receipt response contract', () {
      final draft = TransactionDraft.fromJson({
        'merchant': 'MİGROS',
        'total_amount_minor': 22050,
        'category': 'Market',
      });

      expect(draft.institutionName, 'MİGROS');
      expect(draft.amountInMinor, 22050);
      expect(draft.category, 'Market');
    });
  });
}
