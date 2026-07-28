/// Raw OCR output or user-confirmed transaction data before persistence.
class TransactionDraft {
  const TransactionDraft({
    required this.institutionName,
    required this.category,
    required this.amount,
  });

  const TransactionDraft.empty()
    : institutionName = '',
      category = '',
      amount = null;

  final String institutionName;
  final String category;
  final double? amount;

  factory TransactionDraft.fromJson(Map<String, dynamic> json) {
    return TransactionDraft(
      institutionName: json['merchant_name']?.toString().trim() ?? '',
      category: json['category']?.toString().trim() ?? '',
      amount: _parseAmount(json['amount']),
    );
  }

  static double? _parseAmount(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim().replaceAll(',', '.') ?? '',
    );
  }
}
