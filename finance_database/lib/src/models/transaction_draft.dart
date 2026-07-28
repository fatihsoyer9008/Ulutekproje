/// OCR'dan gelen veya kullanıcı tarafından onaylanan işlemin, kalıcı depolama
/// öncesindeki ortak uygulama modelidir.
///
/// Para değeri, kayan nokta hatalarını önlemek için her zaman kuruş cinsinden
/// tutulur. Örneğin 220,50 TL, [amountInMinor] alanında `22050` olur.
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

    return _parseMajorAmountToMinor(json['amount']);
  }

  /// Yalnızca eski API cevaplarıyla geriye uyumluluk için ana para birimini
  /// kuruşa çevirir. Hesaplama ondalık sayı kullanmadan metin üzerinden yapılır.
  static int? _parseMajorAmountToMinor(Object? value) {
    if (value == null) return null;
    if (value is int) return value * 100;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final normalized = text.contains(',') && !text.contains('.')
        ? text.replaceAll(',', '.')
        : text;
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) return null;

    final lira = int.parse(match.group(1)!);
    final fraction = match.group(2) ?? '';
    final minor = fraction.isEmpty
        ? 0
        : int.parse(fraction.length == 1 ? '${fraction}0' : fraction);
    return (lira * 100) + minor;
  }
}
