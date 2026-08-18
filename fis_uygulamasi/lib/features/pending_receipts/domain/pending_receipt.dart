import 'package:finance_database/finance_database.dart';

/// n8n'in bir e-postadan çıkarıp `status=draft` ile kaydettiği,
/// kullanıcı onayı bekleyen kişisel fiş.
class PendingReceipt {
  const PendingReceipt({
    required this.id,
    this.merchantName,
    this.totalAmountInMinor,
    required this.currency,
    this.receiptDate,
    this.category,
    this.normalizedOcrText,
    required this.createdAt,
  });

  final String id;
  final String? merchantName;
  final int? totalAmountInMinor;
  final String currency;
  final DateTime? receiptDate;
  final String? category;
  final String? normalizedOcrText;
  final DateTime createdAt;

  factory PendingReceipt.fromJson(Map<String, dynamic> json) => PendingReceipt(
    id: json['id'] as String,
    merchantName: json['merchant_name'] as String?,
    totalAmountInMinor: json['total_amount_in_minor'] as int?,
    currency: json['currency'] as String? ?? 'TRY',
    receiptDate: _parseDate(json['receipt_date']),
    category: json['category'] as String?,
    normalizedOcrText: json['normalized_ocr_text'] as String?,
    createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
  );

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Onay ekranında düzenlenebilmesi için mevcut OCR-onay akışının
  /// kullandığı ortak taslak modeline eşler.
  TransactionDraft toTransactionDraft() => TransactionDraft(
    institutionName: merchantName ?? '',
    category: category ?? '',
    amountInMinor: totalAmountInMinor,
    transactionDate: receiptDate,
    rawOcrText: normalizedOcrText,
  );
}
