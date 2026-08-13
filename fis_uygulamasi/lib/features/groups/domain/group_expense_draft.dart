/// Grup masrafı akışında kullanılan, kişisel işlem taslağından bağımsız model.
///
/// Para alanları daima minor-unit (ör. kuruş) tamsayılarıdır. Bu model henüz
/// backend'e gönderilecek request değildir; Fast Split veya Itemized Split
/// ekranına taşınacak kullanıcı tarafından doğrulanmış OCR verisini temsil eder.
class GroupExpenseDraft {
  GroupExpenseDraft({
    required this.groupId,
    required this.payerUserId,
    required this.merchantName,
    required this.category,
    required this.totalAmountInMinor,
    required this.expenseDate,
    required this.currency,
    required this.rawOcrText,
    required List<GroupExpenseDraftItem> items,
  }) : items = List.unmodifiable(items);

  final String groupId;
  final String payerUserId;
  final String merchantName;
  final String category;
  final int? totalAmountInMinor;
  final DateTime? expenseDate;
  final String currency;
  final String? rawOcrText;
  final List<GroupExpenseDraftItem> items;

  /// Itemized Split yalnızca en az bir ürünün adı ve hesaplanabilir, pozitif
  /// satır toplamı varsa güvenle açılabilir. Eksik tutarlı OCR ürünleri taslakta
  /// korunur ancak kullanıcıyı kilitleyen Itemized Split akışını tetiklemez.
  bool get hasMeaningfulItems => items.any(
    (item) =>
        item.name.trim().isNotEmpty &&
        item.totalAmountInMinor != null &&
        item.totalAmountInMinor! > 0,
  );
}

/// Grup masrafına aktarılmış, düzenlenebilir OCR ürün kalemi.
class GroupExpenseDraftItem {
  const GroupExpenseDraftItem({
    required this.name,
    required this.category,
    required this.quantityMilli,
    required this.unitPriceInMinor,
    required this.totalAmountInMinor,
    required this.taxRateBasisPoints,
    required this.taxAmountInMinor,
  });

  final String name;
  final String? category;
  final int? quantityMilli;
  final int? unitPriceInMinor;
  final int? totalAmountInMinor;
  final int? taxRateBasisPoints;
  final int? taxAmountInMinor;
}
