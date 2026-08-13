enum GroupRole { owner, admin, member }

enum SplitType { equal, percentage, fixedAmount, itemized }

enum ShareStatus { open }

enum ExpenseExtraAmountType { tax, tip, serviceFee, other }

GroupRole _groupRoleFromJson(String value) => GroupRole.values.firstWhere(
  (role) => role.name == value,
  orElse: () => throw FormatException('Unknown group_role: $value'),
);

SplitType _splitTypeFromJson(String value) {
  return switch (value) {
    'equal' => SplitType.equal,
    'percentage' => SplitType.percentage,
    'fixed_amount' => SplitType.fixedAmount,
    'itemized' => SplitType.itemized,
    _ => throw FormatException('Unknown split_type: $value'),
  };
}

String _splitTypeToJson(SplitType value) {
  return switch (value) {
    SplitType.equal => 'equal',
    SplitType.percentage => 'percentage',
    SplitType.fixedAmount => 'fixed_amount',
    SplitType.itemized => 'itemized',
  };
}

ExpenseExtraAmountType _expenseExtraAmountTypeFromJson(String value) {
  return switch (value) {
    'tax' => ExpenseExtraAmountType.tax,
    'tip' => ExpenseExtraAmountType.tip,
    'service_fee' => ExpenseExtraAmountType.serviceFee,
    'other' => ExpenseExtraAmountType.other,
    _ => throw FormatException('Unknown expense_extra_amount_type: $value'),
  };
}

String _expenseExtraAmountTypeToJson(ExpenseExtraAmountType value) {
  return switch (value) {
    ExpenseExtraAmountType.tax => 'tax',
    ExpenseExtraAmountType.tip => 'tip',
    ExpenseExtraAmountType.serviceFee => 'service_fee',
    ExpenseExtraAmountType.other => 'other',
  };
}

ShareStatus _shareStatusFromJson(String value) => ShareStatus.values.firstWhere(
  (status) => status.name == value,
  orElse: () => throw FormatException('Unknown share_status: $value'),
);

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.currency,
    required this.memberCount,
    required this.currentUserRole,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  factory Group.fromJson(Map<String, Object?> json) {
    return Group(
      id: json['id']! as String,
      name: json['name']! as String,
      description: json['description'] as String?,
      currency: json['currency']! as String,
      memberCount: json['member_count']! as int,
      currentUserRole: _groupRoleFromJson(json['current_user_role']! as String),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at']! as String,
      updatedAt: json['updated_at']! as String,
      archivedAt: json['archived_at'] as String?,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String currency;
  final int memberCount;
  final GroupRole currentUserRole;
  final String? createdBy;
  final String createdAt;
  final String updatedAt;
  final String? archivedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'description': description,
    'currency': currency,
    'member_count': memberCount,
    'current_user_role': currentUserRole.name,
    'created_by': createdBy,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'archived_at': archivedAt,
  };
}

class GroupDetail extends Group {
  const GroupDetail({
    required super.id,
    required super.name,
    required super.description,
    required super.currency,
    required super.memberCount,
    required super.currentUserRole,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
    required super.archivedAt,
    required this.members,
  });

  factory GroupDetail.fromJson(Map<String, Object?> json) {
    return GroupDetail(
      id: json['id']! as String,
      name: json['name']! as String,
      description: json['description'] as String?,
      currency: json['currency']! as String,
      memberCount: json['member_count']! as int,
      currentUserRole: _groupRoleFromJson(json['current_user_role']! as String),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at']! as String,
      updatedAt: json['updated_at']! as String,
      archivedAt: json['archived_at'] as String?,
      members: (json['members']! as List<Object?>)
          .map((item) => GroupMember.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
    );
  }

  final List<GroupMember> members;

  GroupDetail copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    int? memberCount,
    GroupRole? currentUserRole,
    String? updatedAt,
    String? archivedAt,
    List<GroupMember>? members,
  }) {
    return GroupDetail(
      id: id,
      name: name ?? this.name,
      description: clearDescription ? null : description ?? this.description,
      currency: currency,
      memberCount: memberCount ?? this.memberCount,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      members: members ?? this.members,
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'members': members.map((member) => member.toJson()).toList(growable: false),
  };
}

class GroupMember {
  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    required this.leftAt,
  });

  factory GroupMember.fromJson(Map<String, Object?> json) {
    return GroupMember(
      groupId: json['group_id']! as String,
      userId: json['user_id']! as String,
      displayName: json['display_name']! as String,
      role: _groupRoleFromJson(json['role']! as String),
      joinedAt: json['joined_at']! as String,
      leftAt: json['left_at'] as String?,
    );
  }

  final String groupId;
  final String userId;
  final String displayName;
  final GroupRole role;
  final String joinedAt;
  final String? leftAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'group_id': groupId,
    'user_id': userId,
    'display_name': displayName,
    'role': role.name,
    'joined_at': joinedAt,
    'left_at': leftAt,
  };
}

class ExpenseShare {
  const ExpenseShare({
    required this.expenseId,
    required this.userId,
    required this.displayName,
    required this.amountInMinor,
    required this.status,
    required this.settledAt,
  });

  factory ExpenseShare.fromJson(Map<String, Object?> json) {
    return ExpenseShare(
      expenseId: json['expense_id']! as String,
      userId: json['user_id']! as String,
      displayName: json['display_name']! as String,
      amountInMinor: json['amount_in_minor']! as int,
      status: _shareStatusFromJson(json['status']! as String),
      settledAt: json['settled_at'] as String?,
    );
  }

  final String expenseId;
  final String userId;
  final String displayName;
  final int amountInMinor;
  final ShareStatus status;
  final String? settledAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'expense_id': expenseId,
    'user_id': userId,
    'display_name': displayName,
    'amount_in_minor': amountInMinor,
    'status': status.name,
    'settled_at': settledAt,
  };
}

class ReceiptLineItemAssignment {
  const ReceiptLineItemAssignment({
    required this.expenseId,
    required this.receiptLineItemId,
    required this.userId,
    required this.amountInMinor,
    required this.quantityShareMilli,
  });

  factory ReceiptLineItemAssignment.fromJson(Map<String, Object?> json) {
    return ReceiptLineItemAssignment(
      expenseId: json['expense_id']! as String,
      receiptLineItemId: json['receipt_line_item_id']! as String,
      userId: json['user_id']! as String,
      amountInMinor: json['amount_in_minor']! as int,
      quantityShareMilli: json['quantity_share_milli'] as int?,
    );
  }

  final String expenseId;
  final String receiptLineItemId;
  final String userId;
  final int amountInMinor;
  final int? quantityShareMilli;

  Map<String, Object?> toJson() => <String, Object?>{
    'expense_id': expenseId,
    'receipt_line_item_id': receiptLineItemId,
    'user_id': userId,
    'amount_in_minor': amountInMinor,
    'quantity_share_milli': quantityShareMilli,
  };
}

class ExpenseExtraAmountShare {
  const ExpenseExtraAmountShare({
    required this.extraAmountId,
    required this.userId,
    required this.amountInMinor,
  });

  factory ExpenseExtraAmountShare.fromJson(Map<String, Object?> json) {
    return ExpenseExtraAmountShare(
      extraAmountId: json['extra_amount_id']! as String,
      userId: json['user_id']! as String,
      amountInMinor: json['amount_in_minor']! as int,
    );
  }

  final String extraAmountId;
  final String userId;
  final int amountInMinor;

  Map<String, Object?> toJson() => <String, Object?>{
    'extra_amount_id': extraAmountId,
    'user_id': userId,
    'amount_in_minor': amountInMinor,
  };
}

class ExpenseExtraAmount {
  const ExpenseExtraAmount({
    required this.id,
    required this.expenseId,
    required this.type,
    required this.label,
    required this.amountInMinor,
    required this.shares,
  });

  factory ExpenseExtraAmount.fromJson(Map<String, Object?> json) {
    return ExpenseExtraAmount(
      id: json['id']! as String,
      expenseId: json['expense_id']! as String,
      type: _expenseExtraAmountTypeFromJson(json['type']! as String),
      label: json['label'] as String?,
      amountInMinor: json['amount_in_minor']! as int,
      shares: (json['shares']! as List<Object?>)
          .map(
            (item) =>
                ExpenseExtraAmountShare.fromJson(item! as Map<String, Object?>),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String expenseId;
  final ExpenseExtraAmountType type;
  final String? label;
  final int amountInMinor;
  final List<ExpenseExtraAmountShare> shares;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'expense_id': expenseId,
    'type': _expenseExtraAmountTypeToJson(type),
    'label': label,
    'amount_in_minor': amountInMinor,
    'shares': shares.map((share) => share.toJson()).toList(growable: false),
  };
}

class GroupExpense {
  const GroupExpense({
    required this.id,
    required this.groupId,
    required this.receiptId,
    required this.payerUserId,
    required this.createdBy,
    required this.title,
    required this.note,
    required this.expenseDate,
    required this.totalAmountInMinor,
    required this.currency,
    required this.splitType,
    required this.isFinanciallyLocked,
    required this.shares,
    required this.lineItemAssignments,
    required this.extraAmounts,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  factory GroupExpense.fromJson(Map<String, Object?> json) {
    return GroupExpense(
      id: json['id']! as String,
      groupId: json['group_id']! as String,
      receiptId: json['receipt_id'] as String?,
      payerUserId: json['payer_user_id']! as String,
      createdBy: json['created_by'] as String?,
      title: json['title']! as String,
      note: json['note'] as String?,
      expenseDate: json['expense_date']! as String,
      totalAmountInMinor: json['total_amount_in_minor']! as int,
      currency: json['currency']! as String,
      splitType: _splitTypeFromJson(json['split_type']! as String),
      isFinanciallyLocked: json['is_financially_locked']! as bool,
      shares: (json['shares']! as List<Object?>)
          .map((item) => ExpenseShare.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
      lineItemAssignments: (json['line_item_assignments']! as List<Object?>)
          .map(
            (item) => ReceiptLineItemAssignment.fromJson(
              item! as Map<String, Object?>,
            ),
          )
          .toList(growable: false),
      extraAmounts: (json['extra_amounts']! as List<Object?>)
          .map(
            (item) =>
                ExpenseExtraAmount.fromJson(item! as Map<String, Object?>),
          )
          .toList(growable: false),
      createdAt: json['created_at']! as String,
      updatedAt: json['updated_at']! as String,
      deletedAt: json['deleted_at'] as String?,
    );
  }

  final String id;
  final String groupId;
  final String? receiptId;
  final String payerUserId;
  final String? createdBy;
  final String title;
  final String? note;
  final String expenseDate;
  final int totalAmountInMinor;
  final String currency;
  final SplitType splitType;
  final bool isFinanciallyLocked;
  final List<ExpenseShare> shares;
  final List<ReceiptLineItemAssignment> lineItemAssignments;
  final List<ExpenseExtraAmount> extraAmounts;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'group_id': groupId,
    'receipt_id': receiptId,
    'payer_user_id': payerUserId,
    'created_by': createdBy,
    'title': title,
    'note': note,
    'expense_date': expenseDate,
    'total_amount_in_minor': totalAmountInMinor,
    'currency': currency,
    'split_type': _splitTypeToJson(splitType),
    'is_financially_locked': isFinanciallyLocked,
    'shares': shares.map((share) => share.toJson()).toList(growable: false),
    'line_item_assignments': lineItemAssignments
        .map((assignment) => assignment.toJson())
        .toList(growable: false),
    'extra_amounts': extraAmounts
        .map((extraAmount) => extraAmount.toJson())
        .toList(growable: false),
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

class CreateGroupExpenseRequest {
  const CreateGroupExpenseRequest({
    required this.groupId,
    required this.receiptId,
    required this.payerUserId,
    required this.title,
    required this.note,
    required this.expenseDate,
    required this.totalAmountInMinor,
    required this.currency,
    required this.split,
  });

  final String groupId;
  final String? receiptId;
  final String payerUserId;
  final String title;
  final String? note;
  final String expenseDate;
  final int totalAmountInMinor;
  final String currency;
  final ExpenseSplitRequest split;

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

class ExpenseSplitRequest {
  const ExpenseSplitRequest.equal({required this.memberIds})
    : type = SplitType.equal,
      shares = const <ExpenseSplitShareRequest>[];

  const ExpenseSplitRequest.percentage({required this.shares})
    : type = SplitType.percentage,
      memberIds = const <String>[];

  const ExpenseSplitRequest.fixedAmount({required this.shares})
    : type = SplitType.fixedAmount,
      memberIds = const <String>[];

  final SplitType type;
  final List<String> memberIds;
  final List<ExpenseSplitShareRequest> shares;

  Map<String, Object?> toJson() {
    return switch (type) {
      SplitType.equal => <String, Object?>{
        'type': 'equal',
        'member_ids': memberIds,
      },
      SplitType.percentage => <String, Object?>{
        'type': 'percentage',
        'shares': shares.map((share) => share.toJson()).toList(),
      },
      SplitType.fixedAmount => <String, Object?>{
        'type': 'fixed_amount',
        'shares': shares.map((share) => share.toJson()).toList(),
      },
      SplitType.itemized => throw StateError(
        'Fast Split itemized bölüştürmeyi desteklemez.',
      ),
    };
  }
}

class ExpenseSplitShareRequest {
  const ExpenseSplitShareRequest.percentage({
    required this.userId,
    required this.percentageBasisPoints,
  }) : amountInMinor = null;

  const ExpenseSplitShareRequest.fixedAmount({
    required this.userId,
    required this.amountInMinor,
  }) : percentageBasisPoints = null;

  final String userId;
  final int? percentageBasisPoints;
  final int? amountInMinor;

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    if (percentageBasisPoints != null)
      'percentage_basis_points': percentageBasisPoints,
    if (amountInMinor != null) 'amount_in_minor': amountInMinor,
  };
}

class DebtTransfer {
  const DebtTransfer({
    required this.fromUserId,
    required this.toUserId,
    required this.amountInMinor,
  });

  factory DebtTransfer.fromJson(Map<String, Object?> json) {
    return DebtTransfer(
      fromUserId: json['from_user_id']! as String,
      toUserId: json['to_user_id']! as String,
      amountInMinor: json['amount_in_minor']! as int,
    );
  }

  final String fromUserId;
  final String toUserId;
  final int amountInMinor;

  Map<String, Object?> toJson() => <String, Object?>{
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'amount_in_minor': amountInMinor,
  };
}

class Settlement {
  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountInMinor,
    required this.currency,
    required this.settledAt,
    required this.note,
    required this.createdAt,
  });

  factory Settlement.fromJson(Map<String, Object?> json) {
    return Settlement(
      id: json['id']! as String,
      groupId: json['group_id']! as String,
      fromUserId: json['from_user_id']! as String,
      toUserId: json['to_user_id']! as String,
      amountInMinor: json['amount_in_minor']! as int,
      currency: json['currency']! as String,
      settledAt: json['settled_at']! as String,
      note: json['note'] as String?,
      createdAt: json['created_at']! as String,
    );
  }

  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final int amountInMinor;
  final String currency;
  final String settledAt;
  final String? note;
  final String createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'group_id': groupId,
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'amount_in_minor': amountInMinor,
    'currency': currency,
    'settled_at': settledAt,
    'note': note,
    'created_at': createdAt,
  };
}

class DebtBalance {
  const DebtBalance({
    required this.userId,
    required this.displayName,
    required this.netAmountInMinor,
  });

  factory DebtBalance.fromJson(Map<String, Object?> json) {
    return DebtBalance(
      userId: json['user_id']! as String,
      displayName: json['display_name']! as String,
      netAmountInMinor: json['net_amount_in_minor']! as int,
    );
  }

  final String userId;
  final String displayName;
  final int netAmountInMinor;

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'display_name': displayName,
    'net_amount_in_minor': netAmountInMinor,
  };
}

class DebtSummary {
  const DebtSummary({
    required this.groupId,
    required this.currency,
    required this.balances,
    required this.suggestedTransfers,
    required this.generatedAt,
  });

  factory DebtSummary.fromJson(Map<String, Object?> json) {
    return DebtSummary(
      groupId: json['group_id']! as String,
      currency: json['currency']! as String,
      balances: (json['balances']! as List<Object?>)
          .map((item) => DebtBalance.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
      suggestedTransfers: (json['suggested_transfers']! as List<Object?>)
          .map((item) => DebtTransfer.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
      generatedAt: json['generated_at']! as String,
    );
  }

  final String groupId;
  final String currency;
  final List<DebtBalance> balances;
  final List<DebtTransfer> suggestedTransfers;
  final String generatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'group_id': groupId,
    'currency': currency,
    'balances': balances
        .map((balance) => balance.toJson())
        .toList(growable: false),
    'suggested_transfers': suggestedTransfers
        .map((transfer) => transfer.toJson())
        .toList(growable: false),
    'generated_at': generatedAt,
  };
}

class GroupsResponse {
  const GroupsResponse({required this.groups});

  factory GroupsResponse.fromJson(Map<String, Object?> json) {
    return GroupsResponse(
      groups: (json['groups']! as List<Object?>)
          .map((item) => Group.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
    );
  }

  final List<Group> groups;

  Map<String, Object?> toJson() => <String, Object?>{
    'groups': groups.map((group) => group.toJson()).toList(growable: false),
  };
}

class GroupApiFieldError {
  const GroupApiFieldError({required this.field, required this.message});

  factory GroupApiFieldError.fromJson(Map<String, Object?> json) {
    return GroupApiFieldError(
      field: json['field']! as String,
      message: json['message']! as String,
    );
  }

  final String field;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'field': field,
    'message': message,
  };
}

class GroupApiErrorDetail {
  const GroupApiErrorDetail({
    required this.code,
    required this.message,
    this.fieldErrors,
    this.unassignedReceiptLineItemIds,
  });

  factory GroupApiErrorDetail.fromJson(Map<String, Object?> json) {
    final fieldErrorsJson = json['field_errors'] as List<Object?>?;
    final unassignedIdsJson =
        json['unassigned_receipt_line_item_ids'] as List<Object?>?;
    return GroupApiErrorDetail(
      code: json['code']! as String,
      message: json['message']! as String,
      fieldErrors: fieldErrorsJson
          ?.map(
            (item) =>
                GroupApiFieldError.fromJson(item! as Map<String, Object?>),
          )
          .toList(growable: false),
      unassignedReceiptLineItemIds: unassignedIdsJson
          ?.map((item) => item! as String)
          .toList(growable: false),
    );
  }

  final String code;
  final String message;
  final List<GroupApiFieldError>? fieldErrors;
  final List<String>? unassignedReceiptLineItemIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    if (fieldErrors != null)
      'field_errors': fieldErrors!
          .map((error) => error.toJson())
          .toList(growable: false),
    if (unassignedReceiptLineItemIds != null)
      'unassigned_receipt_line_item_ids': unassignedReceiptLineItemIds,
  };
}

class GroupApiError {
  const GroupApiError({required this.detail});

  factory GroupApiError.fromJson(Map<String, Object?> json) {
    return GroupApiError(
      detail: GroupApiErrorDetail.fromJson(
        json['detail']! as Map<String, Object?>,
      ),
    );
  }

  final GroupApiErrorDetail detail;

  Map<String, Object?> toJson() => <String, Object?>{'detail': detail.toJson()};
}

class GroupApiException implements Exception {
  const GroupApiException({required this.statusCode, required this.error});

  final int statusCode;
  final GroupApiError error;

  String get code => error.detail.code;

  @override
  String toString() => 'GroupApiException($statusCode, $code)';
}
