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

class ItemizedLineShareInput {
  const ItemizedLineShareInput({
    required this.receiptLineItemId,
    required this.userId,
    required this.amountInMinor,
    required this.quantityShareMilli,
  });

  final String receiptLineItemId;
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

class ItemizedExpenseRequest {
  const ItemizedExpenseRequest({
    required this.groupId,
    required this.receiptId,
    required this.title,
    required this.payerUserId,
    required this.expenseDate,
    required this.totalAmountInMinor,
    required this.currency,
    required this.lineShares,
    required this.extraShares,
  });

  final String groupId;
  final String receiptId;
  final String title;
  final String payerUserId;
  final String expenseDate;
  final int totalAmountInMinor;
  final String currency;
  final List<ItemizedLineShareInput> lineShares;
  final List<ItemizedExtraShareInput> extraShares;
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

  Future<void> createInvitation({
    required String groupId,
    required String email,
    GroupRole role = GroupRole.member,
  });

  Future<GroupMember> acceptInvitation(String token);

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
