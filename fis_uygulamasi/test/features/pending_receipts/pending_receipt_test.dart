import 'package:app_main/features/pending_receipts/domain/pending_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson alanları backend şemasından ayrıştırır', () {
    final receipt = PendingReceipt.fromJson({
      'id': 'receipt-1',
      'merchant_name': 'Örnek Market',
      'total_amount_in_minor': 12550,
      'currency': 'TRY',
      'receipt_date': '2026-08-17T10:00:00Z',
      'category': 'market',
      'normalized_ocr_text': 'ÖRNEK MARKET\nTOPLAM 125,50 TL',
      'created_at': '2026-08-17T12:30:00Z',
    });

    expect(receipt.id, 'receipt-1');
    expect(receipt.merchantName, 'Örnek Market');
    expect(receipt.totalAmountInMinor, 12550);
    expect(receipt.currency, 'TRY');
    expect(receipt.receiptDate, DateTime.parse('2026-08-17T10:00:00Z'));
    expect(receipt.category, 'market');
    expect(receipt.normalizedOcrText, 'ÖRNEK MARKET\nTOPLAM 125,50 TL');
  });

  test('fromJson eksik opsiyonel alanlarla da çalışır', () {
    final receipt = PendingReceipt.fromJson({
      'id': 'receipt-2',
      'currency': 'TRY',
      'created_at': '2026-08-17T12:30:00Z',
    });

    expect(receipt.merchantName, isNull);
    expect(receipt.totalAmountInMinor, isNull);
    expect(receipt.receiptDate, isNull);
    expect(receipt.category, isNull);
  });

  test('toTransactionDraft mevcut taslak modeline eşler', () {
    final receipt = PendingReceipt.fromJson({
      'id': 'receipt-1',
      'merchant_name': 'Örnek Market',
      'total_amount_in_minor': 12550,
      'currency': 'TRY',
      'receipt_date': '2026-08-17T10:00:00Z',
      'category': 'market',
      'normalized_ocr_text': 'ÖRNEK MARKET',
      'created_at': '2026-08-17T12:30:00Z',
    });

    final draft = receipt.toTransactionDraft();

    expect(draft.institutionName, 'Örnek Market');
    expect(draft.category, 'market');
    expect(draft.amountInMinor, 12550);
    expect(draft.transactionDate, DateTime.parse('2026-08-17T10:00:00Z'));
    expect(draft.rawOcrText, 'ÖRNEK MARKET');
  });
}
