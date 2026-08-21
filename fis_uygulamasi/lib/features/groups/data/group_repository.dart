import '../domain/group_models.dart';

class GroupRepositoryCapabilities {
  const GroupRepositoryCapabilities({required this.supportsInvitations});

  final bool supportsInvitations;
}

class FastSplitExpenseRequest {
  const FastSplitExpenseRequest({
    required this.groupId,
    required this.title,
    required this.payerUserId,
    required this.expenseDate,
    required this.totalAmountInMinor,
    required this.currency,
    required this.splitType,
    required this.orderedMemberIds,
    this.percentageBasisPoints = const {},
    this.fixedAmountsInMinor = const {},
  });

  final String groupId;
  final String title;
  final String payerUserId;
  final String expenseDate;
  final int totalAmountInMinor;
  final String currency;
  final SplitType splitType;
  final List<String> orderedMemberIds;
  final Map<String, int> percentageBasisPoints;
  final Map<String, int> fixedAmountsInMinor;
}

class ItemizedReceiptDraftLineInput {
  const ItemizedReceiptDraftLineInput({
    required this.position,
    required this.name,
    required this.category,
    required this.quantityMilli,
    required this.unitPriceInMinor,
    required this.totalAmountInMinor,
    required this.taxRateBasisPoints,
    required this.taxAmountInMinor,
  });

  final int position;
  final String name;
  final String? category;
  final int? quantityMilli;
  final int? unitPriceInMinor;
  final int totalAmountInMinor;
  final int? taxRateBasisPoints;
  final int? taxAmountInMinor;
}

class ItemizedReceiptDraftInput {
  const ItemizedReceiptDraftInput({
    required this.merchantName,
    required this.category,
    required this.rawOcrText,
    required this.lineItems,
  });

  final String? merchantName;
  final String? category;
  final String? rawOcrText;
  final List<ItemizedReceiptDraftLineInput> lineItems;
}

class ItemizedLineShareInput {
  const ItemizedLineShareInput({
    this.receiptLineItemId,
    this.receiptLineItemPosition,
    required this.userId,
    required this.amountInMinor,
    required this.quantityShareMilli,
  }) : assert(
         (receiptLineItemId == null) != (receiptLineItemPosition == null),
         'Tam olarak bir satır referansı verilmelidir.',
       );

  final String? receiptLineItemId;
  final int? receiptLineItemPosition;
  final String userId;
  final int amountInMinor;
  final int? quantityShareMilli;
}

class ItemizedExtraShareInput {
  const ItemizedExtraShareInput({
    required this.userId,
    required this.amountInMinor,
  });

  final String userId;
  final int amountInMinor;
}

class ItemizedExtraAmountInput {
  const ItemizedExtraAmountInput({
    required this.type,
    this.label,
    required this.amountInMinor,
    required this.shares,
  });

  final ExpenseExtraAmountType type;
  final String? label;
  final int amountInMinor;
  final List<ItemizedExtraShareInput> shares;
}

class ItemizedExpenseRequest {
  const ItemizedExpenseRequest({
    required this.groupId,
    this.receiptId,
    this.receiptDraft,
    required this.title,
    required this.payerUserId,
    required this.expenseDate,
    required this.totalAmountInMinor,
    required this.currency,
    required this.lineShares,
    required this.extraShares,
    this.extraAmounts = const <ItemizedExtraAmountInput>[],
  }) : assert(
         (receiptId == null) != (receiptDraft == null),
         'Tam olarak bir fiş kaynağı verilmelidir.',
       );

  final String groupId;
  final String? receiptId;
  final ItemizedReceiptDraftInput? receiptDraft;
  final String title;
  final String payerUserId;
  final String expenseDate;
  final int totalAmountInMinor;
  final String currency;
  final List<ItemizedLineShareInput> lineShares;
  final List<ItemizedExtraShareInput> extraShares;
  final List<ItemizedExtraAmountInput> extraAmounts;
}

abstract interface class GroupExpenseRepository {
  Future<List<GroupExpense>> listExpenses(String groupId);

  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  });

  Future<GroupExpense> createExpense(
    CreateGroupExpenseRequest request, {
    required String idempotencyKey,
  });

  Future<GroupExpense> createFastSplit(
    FastSplitExpenseRequest request, {
    required String idempotencyKey,
  });

  Future<GroupExpense> createItemizedSplit(
    ItemizedExpenseRequest request, {
    required String idempotencyKey,
  });
}

abstract interface class DebtSummaryRepository {
  Future<DebtSummary> getDebtSummary(String groupId);
}

abstract interface class GroupRepository
    implements GroupExpenseRepository, DebtSummaryRepository {
  GroupRepositoryCapabilities get capabilities;

  Future<GroupsResponse> listGroups({bool includeArchived = false});

  Future<GroupDetail> getGroup(String groupId);

  Future<List<GroupMember>> listMembers(String groupId);

  Future<GroupDetail> createGroup({
    required String name,
    String? description,
    String currency = 'TRY',
  });

  Future<GroupDetail> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool clearDescription = false,
  });

  Future<void> archiveGroup(String groupId);

  Future<void> leaveGroup(String groupId);

  Future<void> createInvitation({
    required String groupId,
    required String email,
    GroupRole role = GroupRole.member,
  });

  Future<GroupMember> acceptInvitation(String token);

  Future<List<PendingGroupInvitation>> listPendingInvitations();

  Future<GroupMember> acceptInvitationById(String invitationId);

  Future<GroupMember> addMember({
    required String groupId,
    required String userId,
    required String displayName,
    GroupRole role = GroupRole.member,
  });

  Future<void> removeMember({required String groupId, required String userId});

  Future<List<Settlement>> listSettlements(String groupId);

  Future<Settlement> createSettlement(
    Settlement settlement, {
    required String idempotencyKey,
  });
}
