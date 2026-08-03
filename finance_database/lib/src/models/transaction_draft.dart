/// OCR'dan gelen veya kullanıcının onayladığı işlemin, kalıcı depolama
/// öncesindeki ortak uygulama modelidir.
///
/// Para değeri, kayan nokta hatalarını önlemek için her zaman kuruş cinsinden
/// tutulur. Örneğin 220,50 TL, [amountInMinor] alanında `22050` olur.
class TransactionDraft {
  const TransactionDraft({
    required this.institutionName,
    required this.category,
    required this.amountInMinor,
    this.transactionDate,
    this.rawOcrText,
    this.receiptItems = const [],
  });

  const TransactionDraft.empty()
    : institutionName = '',
      category = '',
      amountInMinor = null,
      transactionDate = null,
      rawOcrText = null,
      receiptItems = const [];

  final String institutionName;
  final String category;
  final int? amountInMinor;

  /// Backend'in fişten çıkardığı veya kullanıcının onay ekranında seçtiği tarih.
  final DateTime? transactionDate;

  /// Tarayıcının ürettiği, backend'e gönderilen ham OCR metni.
  final String? rawOcrText;
  final List<ReceiptItem> receiptItems;

  factory TransactionDraft.fromJson(Map<String, dynamic> json) {
    return TransactionDraft(
      institutionName:
          (json['merchant'] ?? json['merchant_name'])?.toString().trim() ?? '',
      category: json['category']?.toString().trim() ?? '',
      amountInMinor: _parseAmountInMinor(json),
      transactionDate: _parseTransactionDate(json['date']),
      rawOcrText: _nullIfBlank(json['raw_ocr_text']),
      receiptItems: _parseReceiptItems(json['items']),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'merchant_name': institutionName,
      'category': category,
      'amountInMinor': amountInMinor,
    };

    if (transactionDate != null) {
      json['date'] = transactionDate!.toIso8601String();
    }

    if (rawOcrText != null) {
      json['raw_ocr_text'] = rawOcrText;
    }
    if (receiptItems.isNotEmpty) {
      json['items'] = receiptItems.map((item) => item.toJson()).toList();
    }

    return json;
  }

  static DateTime? _parseTransactionDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final text = value.toString().trim();
    return text.isEmpty ? null : DateTime.tryParse(text);
  }

  static String? _nullIfBlank(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static List<ReceiptItem> _parseReceiptItems(Object? value) {
    if (value is! List) return const [];
    final items = <ReceiptItem>[];
    for (final item in value) {
      if (item is! Map) continue;
      final json = <String, dynamic>{
        for (final entry in item.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
      items.add(ReceiptItem.fromJson(json));
    }
    return List.unmodifiable(items);
  }

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
  /// kuruşa çevirir. Hesaplama ondalık sayı kullanmadan metin üzerinde yapılır.
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

String _stringOrEmpty(Object? value) => value?.toString().trim() ?? '';

String? _nullIfBlank(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _parseNonNegativeInt(Object? value) {
  final parsed =
      value is int ? value : int.tryParse(value?.toString().trim() ?? '');
  return parsed == null || parsed < 0 ? null : parsed;
}

double? _parseNonNegativeDouble(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().trim() ?? '');
  return parsed == null || !parsed.isFinite || parsed < 0 ? null : parsed;
}

void _putIfNotNull(Map<String, dynamic> json, String key, Object? value) {
  if (value != null) json[key] = value;
}
/// A single product extracted from a receipt.
///
/// Monetary values are always stored in minor units. All fields apart from the
/// name are nullable because receipt parsers can only reliably infer part of a
/// product row.
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    this.category,
    this.priceMinor,
    this.totalAmountInMinor,
    this.quantity,
    this.unitPriceInMinor,
    this.taxRate,
    this.taxAmountInMinor,
  });

  final String name;
  final String? category;

  /// Legacy API field (`price_minor`). Prefer [unitPriceInMinor] for new code.
  final int? priceMinor;
  final int? totalAmountInMinor;
  final double? quantity;
  final int? unitPriceInMinor;
  final double? taxRate;
  final int? taxAmountInMinor;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
    name: _stringOrEmpty(json['name']),
    category: _nullIfBlank(json['category']),
    priceMinor: _parseNonNegativeInt(
      json['price_minor'] ?? json['priceMinor'],
    ),
    totalAmountInMinor: _parseNonNegativeInt(
      json['total_amount_minor'] ?? json['totalAmountInMinor'],
    ),
    quantity: _parseNonNegativeDouble(json['quantity']),
    unitPriceInMinor: _parseNonNegativeInt(
      json['unit_price_in_minor'] ?? json['unitPriceInMinor'],
    ),
    taxRate: _parseNonNegativeDouble(json['tax_rate'] ?? json['taxRate']),
    taxAmountInMinor: _parseNonNegativeInt(
      json['tax_amount_in_minor'] ?? json['taxAmountInMinor'],
    ),
  );

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'name': name};
    _putIfNotNull(json, 'category', category);
    _putIfNotNull(json, 'price_minor', priceMinor);
    _putIfNotNull(json, 'total_amount_minor', totalAmountInMinor);
    _putIfNotNull(json, 'quantity', quantity);
    _putIfNotNull(json, 'unit_price_in_minor', unitPriceInMinor);
    _putIfNotNull(json, 'tax_rate', taxRate);
    _putIfNotNull(json, 'tax_amount_in_minor', taxAmountInMinor);
    return json;
  }
}
