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

  /// Itemized Split yalnızca liste boş değilse ve bütün ürünler hesaplanabilir
  /// pozitif satır toplamına sahipse güvenle açılabilir. Eksik tutarlı OCR
  /// ürünleri taslakta korunur ancak kullanıcıyı kilitleyen akışı tetiklemez.
  List<GroupExpenseDraftItem> get meaningfulItems => List.unmodifiable(
    items.where(
      (item) =>
          item.name.trim().isNotEmpty &&
          item.totalAmountInMinor != null &&
          item.totalAmountInMinor! > 0,
    ),
  );

  bool get hasMeaningfulItems => meaningfulItems.isNotEmpty;

  int get meaningfulItemsTotalInMinor => meaningfulItems.fold<int>(
    0,
    (total, item) => total + item.totalAmountInMinor!,
  );

  int? get resolvedItemizedTotalInMinor {
    final receiptTotal = totalAmountInMinor;
    if (receiptTotal != null && receiptTotal > 0) return receiptTotal;
    final itemTotal = meaningfulItemsTotalInMinor;
    return itemTotal > 0 ? itemTotal : null;
  }

  bool get itemizedTotalWasDerived =>
      (totalAmountInMinor == null || totalAmountInMinor! <= 0) &&
      resolvedItemizedTotalInMinor != null;
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
