import 'dart:convert';

import '../application/fast_split_calculator.dart';
import '../domain/group_models.dart';
import 'group_repository.dart';

export 'fake_debt_summary_repository.dart';
export 'fake_group_expense_repository.dart';
export 'group_repository.dart';

class FakeGroupRepository implements GroupRepository {
  FakeGroupRepository({
    this.currentUserId = '00000000-0000-4000-8000-000000000001',
    this.currentUserDisplayName = 'Aktif Kullanıcı',
    Iterable<GroupDetail> groups = const <GroupDetail>[],
    Map<String, List<GroupExpense>> expensesByGroup =
        const <String, List<GroupExpense>>{},
    Map<String, DebtSummary> debtSummariesByGroup =
        const <String, DebtSummary>{},
    Map<String, List<Settlement>> settlementsByGroup =
        const <String, List<Settlement>>{},
    this.latency = Duration.zero,
    this.error,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    for (final group in groups) {
      final copy = GroupDetail.fromJson(group.toJson());
      _groupsById[copy.id] = copy;
    }
    for (final entry in expensesByGroup.entries) {
      _expensesByGroup[entry.key] = entry.value
          .map((expense) => GroupExpense.fromJson(expense.toJson()))
          .toList();
    }
    for (final entry in debtSummariesByGroup.entries) {
      _debtSummariesByGroup[entry.key] = DebtSummary.fromJson(
        entry.value.toJson(),
      );
    }
    for (final entry in settlementsByGroup.entries) {
      _settlementsByGroup[entry.key] = entry.value
          .map((settlement) => Settlement.fromJson(settlement.toJson()))
          .toList();
    }
  }

  final String currentUserId;
  final String currentUserDisplayName;
  final Duration latency;
  final GroupApiException? error;
  final DateTime Function() _clock;

  final Map<String, GroupDetail> _groupsById = <String, GroupDetail>{};
  final Map<String, List<GroupExpense>> _expensesByGroup =
      <String, List<GroupExpense>>{};
  final Map<String, DebtSummary> _debtSummariesByGroup =
      <String, DebtSummary>{};
  final Map<String, List<Settlement>> _settlementsByGroup =
      <String, List<Settlement>>{};
  final Map<String, _IdempotentValue<GroupExpense>> _expenseRequests =
      <String, _IdempotentValue<GroupExpense>>{};
  final Map<String, _IdempotentValue<Settlement>> _settlementRequests =
      <String, _IdempotentValue<Settlement>>{};

  int _nextGroupSequence = 100;

  @override
  Future<GroupsResponse> listGroups({bool includeArchived = false}) async {
    await _beforeRequest();
    final groups = _groupsById.values
        .where(_hasCurrentUserMembership)
        .where((group) => includeArchived || group.archivedAt == null)
        .map((group) => Group.fromJson(group.toJson()))
        .toList(growable: false);
    return GroupsResponse(groups: groups);
  }

  @override
  Future<GroupDetail> getGroup(String groupId) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    _requireCurrentUserMembership(group);
    return GroupDetail.fromJson(group.toJson());
  }

  @override
  Future<GroupDetail> createGroup({
    required String name,
    String? description,
    String currency = 'TRY',
  }) async {
    await _beforeRequest();
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 120 || currency != 'TRY') {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Grup bilgileri geçersiz.',
      );
    }
    if (description != null && description.length > 1000) {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Grup açıklaması en fazla 1000 karakter olabilir.',
      );
    }

    final id = _newGroupId();
    final timestamp = _timestamp();
    final owner = GroupMember(
      groupId: id,
      userId: currentUserId,
      displayName: currentUserDisplayName,
      role: GroupRole.owner,
      joinedAt: timestamp,
      leftAt: null,
    );
    final group = GroupDetail(
      id: id,
      name: trimmedName,
      description: description,
      currency: currency,
      memberCount: 1,
      currentUserRole: GroupRole.owner,
      createdBy: currentUserId,
      createdAt: timestamp,
      updatedAt: timestamp,
      archivedAt: null,
      members: <GroupMember>[owner],
    );
    _groupsById[id] = group;
    return GroupDetail.fromJson(group.toJson());
  }

  @override
  Future<GroupDetail> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool clearDescription = false,
  }) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    if (_currentUserRole(group) != GroupRole.owner) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Bu grubu güncelleme yetkiniz yok.',
      );
    }
    if (name == null && description == null && !clearDescription) {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'En az bir alan gönderilmelidir.',
      );
    }
    final trimmedName = name?.trim();
    if (trimmedName != null &&
        (trimmedName.isEmpty || trimmedName.length > 120)) {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Grup adı 1-120 karakter olmalıdır.',
      );
    }
    if (description != null && description.length > 1000) {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Grup açıklaması en fazla 1000 karakter olabilir.',
      );
    }

    final updated = group.copyWith(
      name: trimmedName,
      description: description,
      clearDescription: clearDescription,
      updatedAt: _timestamp(),
    );
    _groupsById[groupId] = updated;
    return GroupDetail.fromJson(updated.toJson());
  }

  @override
  Future<void> archiveGroup(String groupId) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    if (_currentUserRole(group) != GroupRole.owner) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Bu grubu arşivleme yetkiniz yok.',
      );
    }
    final timestamp = _timestamp();
    _groupsById[groupId] = group.copyWith(
      archivedAt: timestamp,
      updatedAt: timestamp,
    );
  }

  @override
  Future<GroupMember> addMember({
    required String groupId,
    required String userId,
    required String displayName,
    GroupRole role = GroupRole.member,
  }) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    final currentRole = _currentUserRole(group);
    if (currentRole != GroupRole.owner && currentRole != GroupRole.admin) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Bu gruba üye ekleme yetkiniz yok.',
      );
    }
    if (currentRole == GroupRole.admin && role != GroupRole.member) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Admin yalnızca member rolünde üye ekleyebilir.',
      );
    }
    if (group.members.any(
      (member) => member.userId == userId && member.leftAt == null,
    )) {
      throw _apiException(
        statusCode: 409,
        code: 'member_already_exists',
        message: 'Kullanıcı zaten aktif grup üyesi.',
      );
    }

    final member = GroupMember(
      groupId: groupId,
      userId: userId,
      displayName: displayName,
      role: role,
      joinedAt: _timestamp(),
      leftAt: null,
    );
    final members = <GroupMember>[...group.members, member];
    _groupsById[groupId] = group.copyWith(
      memberCount: members.where((item) => item.leftAt == null).length,
      members: members,
      updatedAt: _timestamp(),
    );
    return GroupMember.fromJson(member.toJson());
  }

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    _requireCurrentUserMembership(group);
    return (_expensesByGroup[groupId] ?? const <GroupExpense>[])
        .where((expense) => expense.deletedAt == null)
        .map((expense) => GroupExpense.fromJson(expense.toJson()))
        .toList(growable: false);
  }

  @override
  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  }) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    _requireCurrentUserMembership(group);
    final expense = (_expensesByGroup[groupId] ?? const <GroupExpense>[])
        .where((item) => item.id == expenseId && item.deletedAt == null)
        .firstOrNull;
    if (expense == null) {
      throw _apiException(
        statusCode: 404,
        code: 'expense_not_found',
        message: 'Masraf bulunamadı.',
      );
    }
    return GroupExpense.fromJson(expense.toJson());
  }

  @override
  Future<GroupExpense> createExpense(
    GroupExpense expense, {
    required String idempotencyKey,
  }) async {
    await _beforeRequest();
    final group = _requireGroup(expense.groupId);
    _requireCurrentUserMembership(group);
    _validateIdempotencyKey(idempotencyKey);
    _validateExpense(group, expense);

    final fingerprint = jsonEncode(expense.toJson());
    final existing = _expenseRequests[idempotencyKey];
    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        throw _idempotencyConflict();
      }
      return GroupExpense.fromJson(existing.value.toJson());
    }

    final stored = GroupExpense.fromJson(expense.toJson());
    _expensesByGroup
        .putIfAbsent(expense.groupId, () => <GroupExpense>[])
        .add(stored);
    _expenseRequests[idempotencyKey] = _IdempotentValue<GroupExpense>(
      fingerprint: fingerprint,
      value: stored,
    );
    return GroupExpense.fromJson(stored.toJson());
  }

  @override
  Future<GroupExpense> createFastSplit(
    FastSplitExpenseRequest request, {
    required String idempotencyKey,
  }) {
    final now = _timestamp();
    final expenseId = 'local-expense-${_clock().microsecondsSinceEpoch}';
    final group = _requireGroup(request.groupId);
    final members = {for (final member in group.members) member.userId: member};
    final calculation = switch (request.splitType) {
      SplitType.equal => FastSplitCalculator.equal(
        totalAmountInMinor: request.totalAmountInMinor,
        memberIds: request.orderedMemberIds,
      ),
      SplitType.percentage => FastSplitCalculator.percentage(
        totalAmountInMinor: request.totalAmountInMinor,
        memberIds: request.orderedMemberIds,
        percentageBasisPoints: request.percentageBasisPoints,
      ),
      SplitType.fixedAmount => FastSplitCalculator.fixedAmount(
        totalAmountInMinor: request.totalAmountInMinor,
        memberIds: request.orderedMemberIds,
        amountsInMinor: request.fixedAmountsInMinor,
      ),
      SplitType.itemized => throw ArgumentError.value(request.splitType),
    };
    final amounts = {
      for (final share in calculation.shares) share.userId: share.amountInMinor,
    };
    return createExpense(
      GroupExpense(
        id: expenseId,
        groupId: request.groupId,
        receiptId: null,
        payerUserId: request.payerUserId,
        createdBy: currentUserId,
        title: request.title,
        note: null,
        expenseDate: request.expenseDate,
        totalAmountInMinor: request.totalAmountInMinor,
        currency: request.currency,
        splitType: request.splitType,
        isFinanciallyLocked: false,
        shares: [
          for (final userId in request.orderedMemberIds)
            ExpenseShare(
              expenseId: expenseId,
              userId: userId,
              displayName: members[userId]?.displayName ?? 'Silinmiş kullanıcı',
              amountInMinor: amounts[userId] ?? 0,
              status: ShareStatus.open,
              settledAt: null,
            ),
        ],
        lineItemAssignments: const [],
        extraAmounts: const [],
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      ),
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<GroupExpense> createItemizedSplit(
    ItemizedExpenseRequest request, {
    required String idempotencyKey,
  }) {
    final now = _timestamp();
    final expenseId = 'local-expense-${_clock().microsecondsSinceEpoch}';
    final extraAmountId = '$expenseId-extra-1';
    final group = _requireGroup(request.groupId);
    final members = {for (final member in group.members) member.userId: member};
    final totals = <String, int>{};
    for (final share in request.lineShares) {
      totals.update(
        share.userId,
        (value) => value + share.amountInMinor,
        ifAbsent: () => share.amountInMinor,
      );
    }
    for (final share in request.extraShares) {
      totals.update(
        share.userId,
        (value) => value + share.amountInMinor,
        ifAbsent: () => share.amountInMinor,
      );
    }
    return createExpense(
      GroupExpense(
        id: expenseId,
        groupId: request.groupId,
        receiptId: request.receiptId,
        payerUserId: request.payerUserId,
        createdBy: currentUserId,
        title: request.title,
        note: null,
        expenseDate: request.expenseDate,
        totalAmountInMinor: request.totalAmountInMinor,
        currency: request.currency,
        splitType: SplitType.itemized,
        isFinanciallyLocked: false,
        shares: [
          for (final entry in totals.entries)
            ExpenseShare(
              expenseId: expenseId,
              userId: entry.key,
              displayName:
                  members[entry.key]?.displayName ?? 'Silinmiş kullanıcı',
              amountInMinor: entry.value,
              status: ShareStatus.open,
              settledAt: null,
            ),
        ],
        lineItemAssignments: [
          for (final share in request.lineShares)
            ReceiptLineItemAssignment(
              expenseId: expenseId,
              receiptLineItemId: share.receiptLineItemId,
              userId: share.userId,
              amountInMinor: share.amountInMinor,
              quantityShareMilli: share.quantityShareMilli,
            ),
        ],
        extraAmounts: [
          if (request.extraShares.isNotEmpty)
            ExpenseExtraAmount(
              id: extraAmountId,
              expenseId: expenseId,
              type: ExpenseExtraAmountType.other,
              label: 'Fiş toplam farkı',
              amountInMinor: request.extraShares.fold<int>(
                0,
                (total, share) => total + share.amountInMinor,
              ),
              shares: [
                for (final share in request.extraShares)
                  ExpenseExtraAmountShare(
                    extraAmountId: extraAmountId,
                    userId: share.userId,
                    amountInMinor: share.amountInMinor,
                  ),
              ],
            ),
        ],
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      ),
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<DebtSummary> getDebtSummary(String groupId) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    _requireCurrentUserMembership(group);
    final summary = _debtSummariesByGroup[groupId];
    if (summary == null) {
      return DebtSummary(
        groupId: groupId,
        currency: group.currency,
        balances: const <DebtBalance>[],
        suggestedTransfers: const <DebtTransfer>[],
        generatedAt: _timestamp(),
      );
    }
    return DebtSummary.fromJson(summary.toJson());
  }

  @override
  Future<List<Settlement>> listSettlements(String groupId) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    _requireCurrentUserMembership(group);
    return (_settlementsByGroup[groupId] ?? const <Settlement>[])
        .map((settlement) => Settlement.fromJson(settlement.toJson()))
        .toList(growable: false);
  }

  @override
  Future<Settlement> createSettlement(
    Settlement settlement, {
    required String idempotencyKey,
  }) async {
    await _beforeRequest();
    final group = _requireGroup(settlement.groupId);
    _requireCurrentUserMembership(group);
    _validateIdempotencyKey(idempotencyKey);
    if (settlement.fromUserId != currentUserId ||
        settlement.fromUserId == settlement.toUserId ||
        settlement.amountInMinor <= 0 ||
        settlement.currency != group.currency ||
        !_isActiveMember(group, settlement.toUserId)) {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Ödeme bilgileri geçersiz.',
      );
    }

    final fingerprint = jsonEncode(settlement.toJson());
    final existing = _settlementRequests[idempotencyKey];
    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        throw _idempotencyConflict();
      }
      return Settlement.fromJson(existing.value.toJson());
    }

    final stored = Settlement.fromJson(settlement.toJson());
    _settlementsByGroup
        .putIfAbsent(settlement.groupId, () => <Settlement>[])
        .add(stored);
    _settlementRequests[idempotencyKey] = _IdempotentValue<Settlement>(
      fingerprint: fingerprint,
      value: stored,
    );
    return Settlement.fromJson(stored.toJson());
  }

  Future<void> _beforeRequest() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    if (error case final configuredError?) {
      throw configuredError;
    }
  }

  GroupDetail _requireGroup(String groupId) {
    final group = _groupsById[groupId];
    if (group == null) {
      throw _apiException(
        statusCode: 404,
        code: 'group_not_found',
        message: 'Grup bulunamadı.',
      );
    }
    return group;
  }

  bool _hasCurrentUserMembership(GroupDetail group) {
    return _isActiveMember(group, currentUserId);
  }

  bool _isActiveMember(GroupDetail group, String userId) {
    return group.members.any(
      (member) => member.userId == userId && member.leftAt == null,
    );
  }

  GroupRole? _currentUserRole(GroupDetail group) {
    for (final member in group.members) {
      if (member.userId == currentUserId && member.leftAt == null) {
        return member.role;
      }
    }
    return null;
  }

  void _requireCurrentUserMembership(GroupDetail group) {
    if (!_hasCurrentUserMembership(group)) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Bu grup için yetkiniz yok.',
      );
    }
  }

  void _validateExpense(GroupDetail group, GroupExpense expense) {
    final shareTotal = expense.shares.fold<int>(
      0,
      (total, share) => total + share.amountInMinor,
    );
    final hasInvalidShare = expense.shares.any(
      (share) =>
          share.expenseId != expense.id ||
          share.amountInMinor < 0 ||
          share.status != ShareStatus.open ||
          share.settledAt != null ||
          !_isActiveMember(group, share.userId),
    );
    final hasInvalidAssignment = expense.lineItemAssignments.any(
      (assignment) =>
          assignment.expenseId != expense.id ||
          assignment.amountInMinor < 0 ||
          !_isActiveMember(group, assignment.userId),
    );
    if (expense.totalAmountInMinor <= 0 ||
        expense.currency != group.currency ||
        !_isActiveMember(group, expense.payerUserId) ||
        shareTotal != expense.totalAmountInMinor ||
        hasInvalidShare ||
        hasInvalidAssignment ||
        (expense.splitType == SplitType.itemized &&
            expense.receiptId == null) ||
        (expense.splitType != SplitType.itemized &&
            expense.lineItemAssignments.isNotEmpty)) {
      throw _apiException(
        statusCode: 422,
        code: 'invalid_split_total',
        message: 'Payların toplamı masraf toplamına eşit olmalıdır.',
      );
    }
  }

  void _validateIdempotencyKey(String key) {
    if (key.length < 8 || key.length > 128) {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Idempotency-Key 8-128 karakter olmalıdır.',
      );
    }
  }

  GroupApiException _idempotencyConflict() => _apiException(
    statusCode: 409,
    code: 'idempotency_conflict',
    message: 'Idempotency anahtarı farklı bir istekle kullanıldı.',
  );

  String _timestamp() => _clock().toUtc().toIso8601String();

  String _newGroupId() {
    final suffix = _nextGroupSequence.toString().padLeft(12, '0');
    _nextGroupSequence += 1;
    return '10000000-0000-4000-8000-$suffix';
  }
}

class _IdempotentValue<T> {
  const _IdempotentValue({required this.fingerprint, required this.value});

  final String fingerprint;
  final T value;
}

GroupApiException _apiException({
  required int statusCode,
  required String code,
  required String message,
  List<GroupApiFieldError>? fieldErrors,
}) {
  return GroupApiException(
    statusCode: statusCode,
    error: GroupApiError(
      detail: GroupApiErrorDetail(
        code: code,
        message: message,
        fieldErrors: fieldErrors,
      ),
    ),
  );
}
