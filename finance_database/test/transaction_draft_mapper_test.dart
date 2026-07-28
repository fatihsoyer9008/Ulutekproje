import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionDraftMapper', () {
    test('maps a completed draft to its persisted representation', () {
      final entity = const TransactionDraft(
        institutionName: ' Migros ',
        category: 'Market',
        amount: 12.50,
      ).toTransactionEntity(
        source: TransactionSource.ocrLlm,
        date: DateTime(2026, 7, 28),
        createdAt: DateTime(2026, 7, 27),
        rawOcrText: ' receipt ',
        note: ' weekly shopping ',
      );

      expect(entity.amountInMinor, 1250);
      expect(entity.category, TransactionCategory.market);
      expect(entity.merchantName, 'Migros');
      expect(entity.source, TransactionSource.ocrLlm);
      expect(entity.date, DateTime(2026, 7, 28));
      expect(entity.createdAt, DateTime(2026, 7, 27));
      expect(entity.updatedAt, DateTime(2026, 7, 27));
      expect(entity.rawOcrText, 'receipt');
      expect(entity.note, 'weekly shopping');
    });

    test('uses safe defaults for incomplete draft', () {
      final entity = const TransactionDraft.empty().toTransactionEntity(
        date: DateTime(2026, 7, 28),
        createdAt: DateTime(2026, 7, 27),
        rawOcrText: ' ',
        note: ' ',
      );

      expect(entity.amountInMinor, 0);
      expect(entity.category, TransactionCategory.diger);
      expect(entity.merchantName, isNull);
      expect(entity.source, TransactionSource.manual);
      expect(entity.rawOcrText, isNull);
      expect(entity.note, isNull);
      expect(entity.updatedAt, DateTime(2026, 7, 27));
    });

    test('negative amount becomes zero', () {
      final entity = const TransactionDraft(
        institutionName: 'Migros',
        category: 'Market',
        amount: -150,
      ).toTransactionEntity();

      expect(entity.amountInMinor, 0);
    });

    test('null amount becomes zero', () {
      final entity = const TransactionDraft(
        institutionName: 'Migros',
        category: 'Market',
        amount: null,
      ).toTransactionEntity();

      expect(entity.amountInMinor, 0);
    });

    test('caps an amount that cannot fit in Isar', () {
      final entity = const TransactionDraft(
        institutionName: '',
        category: '',
        amount: 1e308,
      ).toTransactionEntity();

      expect(entity.amountInMinor, 9223372036854775807);
    });

    test('maps Turkish category names', () {
      final entity = const TransactionDraft(
        institutionName: 'İETT',
        category: 'Ulaşım',
        amount: 18.75,
      ).toTransactionEntity();

      expect(entity.category, TransactionCategory.ulasim);
    });

    test('maps entity back to draft', () {
      final entity = TransactionEntity()
        ..amountInMinor = 1875
        ..category = TransactionCategory.ulasim
        ..merchantName = 'İETT'
        ..source = TransactionSource.manual
        ..date = DateTime(2026, 7, 28)
        ..createdAt = DateTime(2026, 7, 28)
        ..updatedAt = DateTime(2026, 7, 28);

      final draft = entity.toTransactionDraft();

      expect(draft.institutionName, 'İETT');
      expect(draft.category, 'Ulaşım');
      expect(draft.amount, 18.75);
    });

    test('unknown category defaults to diger', () {
      final entity = const TransactionDraft(
        institutionName: 'Test',
        category: 'BilinmeyenKategori',
        amount: 20,
      ).toTransactionEntity();

      expect(entity.category, TransactionCategory.diger);
    });

    test('blank merchant name becomes null', () {
      final entity = const TransactionDraft(
        institutionName: '   ',
        category: 'Market',
        amount: 10,
      ).toTransactionEntity();

      expect(entity.merchantName, isNull);
    });
  });
}