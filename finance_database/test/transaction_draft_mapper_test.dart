import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionDraftMapper', () {
    test('maps a completed draft without changing minor units', () {
      final entity =
          const TransactionDraft(
            institutionName: ' Migros ',
            category: 'Market',
            amountInMinor: 1250,
          ).toTransactionEntity(
            source: TransactionSource.ocrLlm,
            transactionType: TransactionType.income,
            date: DateTime(2026, 7, 28),
            createdAt: DateTime(2026, 7, 27),
            rawOcrText: ' receipt ',
            note: ' weekly shopping ',
          );

      expect(entity.amountInMinor, 1250);
      expect(entity.category, TransactionCategory.market);
      expect(entity.merchantName, 'Migros');
      expect(entity.source, TransactionSource.ocrLlm);
      expect(entity.transactionType, TransactionType.income);
      expect(entity.date, DateTime(2026, 7, 28));
      expect(entity.createdAt, DateTime(2026, 7, 27));
      expect(entity.updatedAt, DateTime(2026, 7, 27));
      expect(entity.rawOcrText, 'receipt');
      expect(entity.note, 'weekly shopping');
    });

    test('draft tarihini ve OCR metnini Isar kaydına aktarır', () {
      final receiptDate = DateTime.utc(2026, 7, 30, 12, 15);

      final entity = TransactionDraft(
        institutionName: 'Migros',
        category: 'Market',
        amountInMinor: 2550,
        transactionDate: receiptDate,
        rawOcrText: 'MIGROS\nTOPLAM 25,50 TL',
      ).toTransactionEntity(source: TransactionSource.ocrLlm);

      expect(entity.date, receiptDate);
      expect(entity.rawOcrText, 'MIGROS\nTOPLAM 25,50 TL');
    });

    test('uses safe defaults for an incomplete draft', () {
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
      expect(entity.transactionType, TransactionType.expense);
      expect(entity.rawOcrText, isNull);
      expect(entity.note, isNull);
      expect(entity.updatedAt, DateTime(2026, 7, 27));
    });

    test('negative and null amounts become zero', () {
      final negative = const TransactionDraft(
        institutionName: 'Migros',
        category: 'Market',
        amountInMinor: -15000,
      ).toTransactionEntity();
      final missing = const TransactionDraft(
        institutionName: 'Migros',
        category: 'Market',
        amountInMinor: null,
      ).toTransactionEntity();

      expect(negative.amountInMinor, 0);
      expect(missing.amountInMinor, 0);
    });

    test('preserves the maximum Isar Int64 amount', () {
      final entity = const TransactionDraft(
        institutionName: '',
        category: '',
        amountInMinor: 9223372036854775807,
      ).toTransactionEntity();

      expect(entity.amountInMinor, 9223372036854775807);
    });

    test('maps Turkish category names in both directions', () {
      final entity = const TransactionDraft(
        institutionName: 'İETT',
        category: 'Ulaşım',
        amountInMinor: 1875,
      ).toTransactionEntity();

      expect(entity.category, TransactionCategory.ulasim);
      expect(entity.toTransactionDraft().category, 'Ulaşım');
      expect(entity.toTransactionDraft().amountInMinor, 1875);
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
      expect(draft.amountInMinor, 1875);
      expect(draft.transactionDate, DateTime(2026, 7, 28));
    });

    test('unknown category and blank merchant use safe defaults', () {
      final entity = const TransactionDraft(
        institutionName: '   ',
        category: 'BilinmeyenKategori',
        amountInMinor: 2000,
      ).toTransactionEntity();

      expect(entity.category, TransactionCategory.diger);
      expect(entity.merchantName, isNull);
    });

    test('ham OCR metnini entity ve draft arasında korur', () {
      const rawOcrText = 'MIGROS TOPLAM 25.50 TL';

      final entity = const TransactionDraft(
        institutionName: 'MIGROS',
        category: 'Market',
        amountInMinor: 2550,
        rawOcrText: rawOcrText,
      ).toTransactionEntity(date: DateTime(2026, 7, 28));

      expect(entity.rawOcrText, rawOcrText);
      expect(entity.toTransactionDraft().rawOcrText, rawOcrText);
    });
  });

  group('TransactionDraft JSON contract', () {
    test('prefers current minor-unit API fields', () {
      for (final key in [
        'total_amount_minor',
        'amountInMinor',
        'amount_in_minor',
      ]) {
        final draft = TransactionDraft.fromJson({
          'merchant': 'MİGROS',
          'category': 'Market',
          key: 22050,
          'amount': '1.00',
        });

        expect(draft.amountInMinor, 22050);
        expect(draft.institutionName, 'MİGROS');
      }
    });

    test('backend tarihini korur, normalize OCR metnini ham metin saymaz', () {
      final draft = TransactionDraft.fromJson({
        'merchant': 'MİGROS',
        'category': 'Market',
        'total_amount_minor': 2550,
        'date': '2026-07-30T12:15:00Z',
        'normalized_ocr_text': 'MİGROS\nTOPLAM 25,50 TL',
      });

      expect(draft.transactionDate, DateTime.parse('2026-07-30T12:15:00Z'));
      expect(draft.rawOcrText, isNull);
    });

    test('supports legacy major amount without floating-point arithmetic', () {
      final draft = TransactionDraft.fromJson({
        'merchant_name': 'Market',
        'category': 'Gıda',
        'amount': '1234.56',
      });

      expect(draft.amountInMinor, 123456);
      expect(draft.toJson(), {
        'merchant_name': 'Market',
        'category': 'Gıda',
        'amountInMinor': 123456,
        'date': null,
      });
    });

    test('uses null and empty defaults for missing data', () {
      final draft = TransactionDraft.fromJson(const {});

      expect(draft.institutionName, '');
      expect(draft.category, '');
      expect(draft.amountInMinor, isNull);
      expect(draft.transactionDate, isNull);
    });

    test('maps the receipt date from JSON into the persisted entity', () {
      final draft = TransactionDraft.fromJson({
        'merchant': 'Market',
        'category': 'Market',
        'total_amount_minor': 2500,
        'date': '2026-07-28T12:00:00Z',
      });

      expect(draft.transactionDate, DateTime.utc(2026, 7, 28, 12));
      expect(draft.toTransactionEntity().date, DateTime.utc(2026, 7, 28, 12));
    });
  });
}
