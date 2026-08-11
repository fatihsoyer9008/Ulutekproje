import 'package:finance_database/finance_database.dart';

class PreparedGroupReceipt {
  const PreparedGroupReceipt({
    required this.draft,
    this.cloudReceiptId,
    this.cloudLineItemIds = const <String?>[],
  });

  final TransactionDraft draft;
  final String? cloudReceiptId;
  final List<String?> cloudLineItemIds;

  bool get hasUsableItems =>
      draft.receiptItems.any((item) => item.name.trim().isNotEmpty);

  bool get canUseItemizedSplit {
    if (cloudReceiptId == null ||
        cloudLineItemIds.length != draft.receiptItems.length) {
      return false;
    }
    for (var index = 0; index < draft.receiptItems.length; index++) {
      if (draft.receiptItems[index].name.trim().isNotEmpty &&
          cloudLineItemIds[index] == null) {
        return false;
      }
    }
    return hasUsableItems;
  }
}
