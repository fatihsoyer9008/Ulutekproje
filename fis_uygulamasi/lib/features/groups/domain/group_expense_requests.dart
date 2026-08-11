import 'group_models.dart';

sealed class GroupExpenseSplitRequest {
  const GroupExpenseSplitRequest();

  SplitType get type;

  Map<String, Object?> toJson();
}

class EqualSplitRequest extends GroupExpenseSplitRequest {
  const EqualSplitRequest({required this.memberIds});

  final List<String> memberIds;

  @override
  SplitType get type => SplitType.equal;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'equal',
    'member_ids': memberIds,
  };
}

class PercentageSplitShareRequest {
  const PercentageSplitShareRequest({
    required this.userId,
    required this.percentageBasisPoints,
  });

  final String userId;
  final int percentageBasisPoints;

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'percentage_basis_points': percentageBasisPoints,
  };
}

class PercentageSplitRequest extends GroupExpenseSplitRequest {
  const PercentageSplitRequest({required this.shares});

  final List<PercentageSplitShareRequest> shares;

  @override
  SplitType get type => SplitType.percentage;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'percentage',
    'shares': shares.map((share) => share.toJson()).toList(growable: false),
  };
}

class FixedAmountSplitShareRequest {
  const FixedAmountSplitShareRequest({
    required this.userId,
    required this.amountInMinor,
  });

  final String userId;
  final int amountInMinor;

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'amount_in_minor': amountInMinor,
  };
}

class FixedAmountSplitRequest extends GroupExpenseSplitRequest {
  const FixedAmountSplitRequest({required this.shares});

  final List<FixedAmountSplitShareRequest> shares;

  @override
  SplitType get type => SplitType.fixedAmount;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'fixed_amount',
    'shares': shares.map((share) => share.toJson()).toList(growable: false),
  };
}

class ItemizedLineItemShareRequest {
  const ItemizedLineItemShareRequest({
    required this.userId,
    required this.amountInMinor,
    required this.quantityShareMilli,
  });

  final String userId;
  final int amountInMinor;
  final int? quantityShareMilli;

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'amount_in_minor': amountInMinor,
    'quantity_share_milli': quantityShareMilli,
  };
}

class ItemizedLineItemRequest {
  const ItemizedLineItemRequest({
    required this.receiptLineItemId,
    required this.shares,
  });

  final String receiptLineItemId;
  final List<ItemizedLineItemShareRequest> shares;

  Map<String, Object?> toJson() => <String, Object?>{
    'receipt_line_item_id': receiptLineItemId,
    'shares': shares.map((share) => share.toJson()).toList(growable: false),
  };
}

class ItemizedSplitRequest extends GroupExpenseSplitRequest {
  const ItemizedSplitRequest({
    required this.lineItems,
    this.extraAmountShares = const <FixedAmountSplitShareRequest>[],
  });

  final List<ItemizedLineItemRequest> lineItems;
  final List<FixedAmountSplitShareRequest> extraAmountShares;

  @override
  SplitType get type => SplitType.itemized;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'itemized',
    'line_items': lineItems
        .map((item) => item.toJson())
        .toList(growable: false),
    'extra_amount_shares': extraAmountShares
        .map((share) => share.toJson())
        .toList(growable: false),
  };
}

class CreateGroupExpenseRequest {
  const CreateGroupExpenseRequest({
    required this.receiptId,
    required this.payerUserId,
    required this.title,
    required this.note,
    required this.expenseDate,
    required this.totalAmountInMinor,
    required this.currency,
    required this.split,
  });

  final String? receiptId;
  final String payerUserId;
  final String title;
  final String? note;
  final String expenseDate;
  final int totalAmountInMinor;
  final String currency;
  final GroupExpenseSplitRequest split;

  Map<String, Object?> toJson() => <String, Object?>{
    'receipt_id': receiptId,
    'payer_user_id': payerUserId,
    'title': title,
    'note': note,
    'expense_date': expenseDate,
    'total_amount_in_minor': totalAmountInMinor,
    'currency': currency,
    'split': split.toJson(),
  };
}
