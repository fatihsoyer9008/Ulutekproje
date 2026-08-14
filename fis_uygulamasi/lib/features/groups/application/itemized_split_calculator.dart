import '../domain/group_models.dart';

class ItemizedReceiptLine {
  const ItemizedReceiptLine({
    required this.receiptLineItemId,
    this.receiptLineItemPosition,
    required this.name,
    required this.quantityMilli,
    required this.unitPriceInMinor,
    required this.totalAmountInMinor,
  });

  final String? receiptLineItemId;
  final int? receiptLineItemPosition;
  final String name;
  final int? quantityMilli;
  final int? unitPriceInMinor;
  final int? totalAmountInMinor;

  bool get isCloudSynced => receiptLineItemId?.trim().isNotEmpty == true;

  bool get isResolvable => isCloudSynced || receiptLineItemPosition != null;

  String selectionKey(int fallbackIndex) {
    final cloudId = receiptLineItemId?.trim();
    if (cloudId != null && cloudId.isNotEmpty) return cloudId;
    final position = receiptLineItemPosition;
    return position == null
        ? 'unresolved-$fallbackIndex'
        : 'draft-position-$position';
  }
}

class ItemizedLineItemShare {
  const ItemizedLineItemShare({
    required this.receiptLineItemId,
    required this.receiptLineItemPosition,
    required this.userId,
    required this.amountInMinor,
    required this.quantityShareMilli,
  });

  final String? receiptLineItemId;
  final int? receiptLineItemPosition;
  final String userId;
  final int amountInMinor;
  final int? quantityShareMilli;

  ReceiptLineItemAssignment toAssignment({required String expenseId}) {
    final cloudId = receiptLineItemId;
    if (cloudId == null) {
      throw StateError(
        'Yerel OCR satırı bulut assignment modeline doğrudan çevrilemez.',
      );
    }
    return ReceiptLineItemAssignment(
      expenseId: expenseId,
      receiptLineItemId: cloudId,
      userId: userId,
      amountInMinor: amountInMinor,
      quantityShareMilli: quantityShareMilli,
    );
  }
}

class ExtraAmountShare {
  const ExtraAmountShare({required this.userId, required this.amountInMinor});

  final String userId;
  final int amountInMinor;

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'amount_in_minor': amountInMinor,
  };
}

class ItemizedSplitCalculation {
  const ItemizedSplitCalculation({
    required this.receiptTotalInMinor,
    required this.lineItemsTotalInMinor,
    required this.lineItemShares,
    required this.extraAmountShares,
    required this.unassignedReceiptLineItemIds,
    required this.hasUnknownLineTotals,
    required this.hasUnsyncedLineItems,
  });

  final int receiptTotalInMinor;
  final int lineItemsTotalInMinor;
  final List<ItemizedLineItemShare> lineItemShares;
  final List<ExtraAmountShare> extraAmountShares;
  final Set<String> unassignedReceiptLineItemIds;
  final bool hasUnknownLineTotals;
  final bool hasUnsyncedLineItems;

  int get extraAmountInMinor => receiptTotalInMinor - lineItemsTotalInMinor;

  int get allocatedAmountInMinor =>
      lineItemShares.fold(0, (sum, share) => sum + share.amountInMinor) +
      extraAmountShares.fold(0, (sum, share) => sum + share.amountInMinor);

  bool get hasNegativeDifference => extraAmountInMinor < 0;

  bool get isBalanced =>
      !hasUnknownLineTotals &&
      !hasUnsyncedLineItems &&
      !hasNegativeDifference &&
      unassignedReceiptLineItemIds.isEmpty &&
      allocatedAmountInMinor == receiptTotalInMinor;

  List<ReceiptLineItemAssignment> toAssignments({required String expenseId}) =>
      lineItemShares
          .map((share) => share.toAssignment(expenseId: expenseId))
          .toList(growable: false);

  Map<String, int> get totalsByUserId {
    final totals = <String, int>{};
    for (final share in lineItemShares) {
      totals.update(
        share.userId,
        (value) => value + share.amountInMinor,
        ifAbsent: () => share.amountInMinor,
      );
    }
    for (final share in extraAmountShares) {
      totals.update(
        share.userId,
        (value) => value + share.amountInMinor,
        ifAbsent: () => share.amountInMinor,
      );
    }
    return Map.unmodifiable(totals);
  }
}

class ItemizedSplitState {
  ItemizedSplitState._({
    required this.receiptTotalInMinor,
    required this.lineItems,
    required this.orderedActiveMemberIds,
    required Map<String, Set<String>> selectedMemberIdsByLineItem,
    required Set<String> selectedExtraMemberIds,
    required this.extraSelectionCustomized,
    required Set<String> serverUnassignedLineItemIds,
  }) : selectedMemberIdsByLineItem = Map.unmodifiable({
         for (final entry in selectedMemberIdsByLineItem.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       selectedExtraMemberIds = Set.unmodifiable(selectedExtraMemberIds),
       serverUnassignedLineItemIds = Set.unmodifiable(
         serverUnassignedLineItemIds,
       );

  factory ItemizedSplitState.initial({
    required int receiptTotalInMinor,
    required List<ItemizedReceiptLine> lineItems,
    required List<String> orderedActiveMemberIds,
  }) {
    _validateMemberIds(orderedActiveMemberIds);
    return ItemizedSplitState._(
      receiptTotalInMinor: receiptTotalInMinor,
      lineItems: List.unmodifiable(lineItems),
      orderedActiveMemberIds: List.unmodifiable(orderedActiveMemberIds),
      selectedMemberIdsByLineItem: const {},
      selectedExtraMemberIds: const {},
      extraSelectionCustomized: false,
      serverUnassignedLineItemIds: const {},
    );
  }

  final int receiptTotalInMinor;
  final List<ItemizedReceiptLine> lineItems;
  final List<String> orderedActiveMemberIds;
  final Map<String, Set<String>> selectedMemberIdsByLineItem;
  final Set<String> selectedExtraMemberIds;
  final bool extraSelectionCustomized;
  final Set<String> serverUnassignedLineItemIds;

  ItemizedSplitState toggleLineItemMember({
    required String receiptLineItemId,
    required String userId,
  }) {
    _requireActiveMember(userId);
    final selections = <String, Set<String>>{
      for (final entry in selectedMemberIdsByLineItem.entries)
        entry.key: {...entry.value},
    };
    final selected = selections.putIfAbsent(receiptLineItemId, () => {});
    selected.contains(userId) ? selected.remove(userId) : selected.add(userId);
    final participants = _participants(selections);
    return ItemizedSplitState._(
      receiptTotalInMinor: receiptTotalInMinor,
      lineItems: lineItems,
      orderedActiveMemberIds: orderedActiveMemberIds,
      selectedMemberIdsByLineItem: selections,
      selectedExtraMemberIds: extraSelectionCustomized
          ? selectedExtraMemberIds
          : participants,
      extraSelectionCustomized: extraSelectionCustomized,
      serverUnassignedLineItemIds: {...serverUnassignedLineItemIds}
        ..remove(receiptLineItemId),
    );
  }

  ItemizedSplitState toggleExtraMember(String userId) {
    _requireActiveMember(userId);
    final selected = {...selectedExtraMemberIds};
    selected.contains(userId) ? selected.remove(userId) : selected.add(userId);
    return ItemizedSplitState._(
      receiptTotalInMinor: receiptTotalInMinor,
      lineItems: lineItems,
      orderedActiveMemberIds: orderedActiveMemberIds,
      selectedMemberIdsByLineItem: selectedMemberIdsByLineItem,
      selectedExtraMemberIds: selected,
      extraSelectionCustomized: true,
      serverUnassignedLineItemIds: serverUnassignedLineItemIds,
    );
  }

  ItemizedSplitState withServerUnassignedLineItems(Iterable<String> ids) =>
      ItemizedSplitState._(
        receiptTotalInMinor: receiptTotalInMinor,
        lineItems: lineItems,
        orderedActiveMemberIds: orderedActiveMemberIds,
        selectedMemberIdsByLineItem: selectedMemberIdsByLineItem,
        selectedExtraMemberIds: selectedExtraMemberIds,
        extraSelectionCustomized: extraSelectionCustomized,
        serverUnassignedLineItemIds: ids.toSet(),
      );

  ItemizedSplitCalculation get calculation => ItemizedSplitCalculator.calculate(
    receiptTotalInMinor: receiptTotalInMinor,
    lineItems: lineItems,
    orderedActiveMemberIds: orderedActiveMemberIds,
    selectedMemberIdsByLineItem: selectedMemberIdsByLineItem,
    selectedExtraMemberIds: selectedExtraMemberIds,
    serverUnassignedLineItemIds: serverUnassignedLineItemIds,
  );

  Set<String> _participants(Map<String, Set<String>> selections) => {
    for (final values in selections.values) ...values,
  };

  void _requireActiveMember(String userId) {
    if (!orderedActiveMemberIds.contains(userId)) {
      throw const FormatException('Yalnızca aktif grup üyeleri seçilebilir.');
    }
  }
}

class ItemizedSplitCalculator {
  const ItemizedSplitCalculator._();

  static ItemizedSplitCalculation calculate({
    required int receiptTotalInMinor,
    required List<ItemizedReceiptLine> lineItems,
    required List<String> orderedActiveMemberIds,
    required Map<String, Set<String>> selectedMemberIdsByLineItem,
    required Set<String> selectedExtraMemberIds,
    Set<String> serverUnassignedLineItemIds = const {},
  }) {
    if (receiptTotalInMinor <= 0) {
      throw const FormatException('Fiş toplamı sıfırdan büyük olmalıdır.');
    }
    _validateMemberIds(orderedActiveMemberIds);
    final activeIds = orderedActiveMemberIds.toSet();
    if (selectedMemberIdsByLineItem.values.any(
          (ids) => ids.any((id) => !activeIds.contains(id)),
        ) ||
        selectedExtraMemberIds.any((id) => !activeIds.contains(id))) {
      throw const FormatException('Yalnızca aktif grup üyeleri seçilebilir.');
    }

    var itemTotal = 0;
    var unknownTotal = false;
    var unsynced = false;
    final shares = <ItemizedLineItemShare>[];
    final unassigned = <String>{...serverUnassignedLineItemIds};

    for (var index = 0; index < lineItems.length; index += 1) {
      final item = lineItems[index];
      final lineId = item.receiptLineItemId;
      final linePosition = item.receiptLineItemPosition;
      final selectionKey = item.selectionKey(index);
      final selected = [
        for (final memberId in orderedActiveMemberIds)
          if (selectedMemberIdsByLineItem[selectionKey]?.contains(memberId) ??
              false)
            memberId,
      ];

      if (!item.isResolvable) unsynced = true;

      final total = item.totalAmountInMinor;
      if (total == null) {
        unknownTotal = true;
      } else {
        if (total < 0) {
          throw const FormatException('Ürün toplamı negatif olamaz.');
        }
        itemTotal += total;
      }

      if (selected.isEmpty) {
        unassigned.add(selectionKey);
        continue;
      }
      if (!item.isResolvable || total == null) continue;

      final amounts = _equalAmounts(total, selected);
      final quantities = item.quantityMilli == null
          ? null
          : _equalAmounts(item.quantityMilli!, selected);

      for (var shareIndex = 0; shareIndex < selected.length; shareIndex += 1) {
        shares.add(
          ItemizedLineItemShare(
            receiptLineItemId: lineId,
            receiptLineItemPosition: linePosition,
            userId: selected[shareIndex],
            amountInMinor: amounts[shareIndex],
            quantityShareMilli: quantities?[shareIndex],
          ),
        );
      }
    }

    final extra = receiptTotalInMinor - itemTotal;
    final orderedExtraIds = [
      for (final id in orderedActiveMemberIds)
        if (selectedExtraMemberIds.contains(id)) id,
    ];
    final extraShares = <ExtraAmountShare>[];
    if (!unknownTotal && extra > 0 && orderedExtraIds.isNotEmpty) {
      final amounts = _equalAmounts(extra, orderedExtraIds);
      for (var index = 0; index < orderedExtraIds.length; index += 1) {
        extraShares.add(
          ExtraAmountShare(
            userId: orderedExtraIds[index],
            amountInMinor: amounts[index],
          ),
        );
      }
    }

    return ItemizedSplitCalculation(
      receiptTotalInMinor: receiptTotalInMinor,
      lineItemsTotalInMinor: itemTotal,
      lineItemShares: List.unmodifiable(shares),
      extraAmountShares: List.unmodifiable(extraShares),
      unassignedReceiptLineItemIds: Set.unmodifiable(unassigned),
      hasUnknownLineTotals: unknownTotal,
      hasUnsyncedLineItems: unsynced,
    );
  }

  static List<int> _equalAmounts(int total, List<String> orderedMemberIds) {
    if (total < 0 || orderedMemberIds.isEmpty) {
      throw const FormatException('Tutar dağıtımı için üye seçilmelidir.');
    }
    final base = total ~/ orderedMemberIds.length;
    final remainder = total.remainder(orderedMemberIds.length);
    return List<int>.generate(
      orderedMemberIds.length,
      (index) => base + (index < remainder ? 1 : 0),
      growable: false,
    );
  }
}

void _validateMemberIds(List<String> memberIds) {
  if (memberIds.any((id) => id.trim().isEmpty) ||
      memberIds.toSet().length != memberIds.length) {
    throw const FormatException('Aktif üye kimlikleri geçersiz.');
  }
}
