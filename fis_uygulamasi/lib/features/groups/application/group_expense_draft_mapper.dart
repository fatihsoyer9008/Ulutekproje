import 'package:finance_database/finance_database.dart';

import '../../transaction_draft/model/receipt_total_validation.dart';
import '../domain/group_expense_draft.dart';

/// Kullanıcının doğruladığı OCR taslağını grup masrafı taslağına dönüştürür.
///
/// Mapper herhangi bir repository'ye yazmaz ve kaynak [TransactionDraft]
/// nesnesini değiştirmez. Böylece kişisel gider kaydı ile grup masrafı akışı
/// birbirinden bağımsız kalır.
class GroupExpenseDraftMapper {
  const GroupExpenseDraftMapper();

  GroupExpenseDraft fromTransactionDraft({
    required TransactionDraft source,
    required String groupId,
    required String payerUserId,
    String currency = 'TRY',
  }) {
    final normalizedGroupId = _requireIdentifier(groupId, 'groupId');
    final normalizedPayerUserId = _requireIdentifier(
      payerUserId,
      'payerUserId',
    );
    final normalizedCurrency = _requireIdentifier(
      currency,
      'currency',
    ).toUpperCase();

    return GroupExpenseDraft(
      groupId: normalizedGroupId,
      payerUserId: normalizedPayerUserId,
      merchantName: source.institutionName.trim(),
      category: source.category.trim(),
      totalAmountInMinor: _nonNegative(source.amountInMinor),
      expenseDate: source.transactionDate,
      currency: normalizedCurrency,
      rawOcrText: _trimmedOrNull(source.rawOcrText),
      items: source.receiptItems
          .where((item) => item.name.trim().isNotEmpty)
          .map(_mapItem)
          .toList(growable: false),
    );
  }

  GroupExpenseDraftItem _mapItem(ReceiptItem item) {
    final quantity = item.quantity;
    final roundedQuantityMilli =
        quantity == null || !quantity.isFinite || quantity <= 0
        ? null
        : (quantity * 1000).round();
    final quantityMilli =
        roundedQuantityMilli == null || roundedQuantityMilli <= 0
        ? null
        : roundedQuantityMilli;
    final taxRate = item.taxRate;
    final taxRateBasisPoints =
        taxRate == null || !taxRate.isFinite || taxRate < 0 || taxRate > 1
        ? null
        : (taxRate * 10000).round();
    final calculatedTotal = ReceiptTotalValidation.calculateItemTotalInMinor(
      item,
    );

    return GroupExpenseDraftItem(
      name: item.name.trim(),
      category: _trimmedOrNull(item.category),
      quantityMilli: quantityMilli,
      unitPriceInMinor: _nonNegative(item.unitPriceInMinor ?? item.priceMinor),
      totalAmountInMinor: _nonNegative(calculatedTotal),
      taxRateBasisPoints: taxRateBasisPoints,
      taxAmountInMinor: _nonNegative(item.taxAmountInMinor),
    );
  }

  String _requireIdentifier(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, 'Boş olamaz.');
    }
    return normalized;
  }

  String? _trimmedOrNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  int? _nonNegative(int? value) => value == null || value < 0 ? null : value;
}
