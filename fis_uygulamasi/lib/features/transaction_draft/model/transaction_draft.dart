import 'turkish_money.dart';

class TransactionDraft {
  const TransactionDraft({
    required this.institutionName,
    required this.category,
    required this.amountInMinor,
  });

  const TransactionDraft.empty()
    : institutionName = '',
      category = '',
      amountInMinor = null;

  final String institutionName;
  final String category;
  final int? amountInMinor;

  factory TransactionDraft.fromJson(Map<String, dynamic> json) {
    return TransactionDraft(
      institutionName:
          (json['merchant'] ?? json['merchant_name'])?.toString().trim() ?? '',
      category: json['category']?.toString().trim() ?? '',
      amountInMinor: _parseAmountInMinor(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'merchant_name': institutionName,
    'category': category,
    'amountInMinor': amountInMinor,
  };

  static int? _parseAmountInMinor(Map<String, dynamic> json) {
    final minorValue =
        json['total_amount_minor'] ??
        json['amountInMinor'] ??
        json['amount_in_minor'];
    if (minorValue != null) {
      return minorValue is int
          ? minorValue
          : int.tryParse(minorValue.toString().trim());
    }
    return parseMajorAmountToMinor(json['amount']);
  }
}
