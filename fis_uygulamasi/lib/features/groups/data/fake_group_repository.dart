import 'dart:convert';

import 'package:finance_database/finance_database.dart';

import '../domain/group_expense_requests.dart';
import '../domain/group_models.dart';
import '../domain/prepared_group_receipt.dart';
import '../domain/split_calculator.dart';
import 'group_mock_data.dart';
import 'group_repository.dart';

export 'group_repository.dart';

class FakeGroupRepository implements GroupRepository {
  factory FakeGroupRepository.sample() => _createDefaultFakeGroupRepository();

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
  final Map<String, Map<String, int>> _preparedReceiptLineAmounts =
      <String, Map<String, int>>{};

  int _nextGroupSequence = 100;
  int _nextReceiptSequence = 100;
  int _nextReceiptLineSequence = 100;
  int _nextExpenseSequence = 100;

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
  Future<PreparedGroupReceipt> prepareReceiptForSharing(
    TransactionDraft draft,
  ) async {
    await _beforeRequest();
    final receiptId = _newReceiptId();
    final lineItemIds = <String?>[];
    final lineAmounts = <String, int>{};
    for (final item in draft.receiptItems) {
      if (item.name.trim().isEmpty) {
        lineItemIds.add(null);
        continue;
      }
      final lineItemId = _newReceiptLineItemId();
      lineItemIds.add(lineItemId);
      lineAmounts[lineItemId] =
          item.totalAmountInMinor ??
          item.priceMinor ??
          item.unitPriceInMinor ??
          0;
    }
    _preparedReceiptLineAmounts[receiptId] = lineAmounts;
    return PreparedGroupReceipt(
      draft: draft,
      cloudReceiptId: receiptId,
      cloudLineItemIds: List<String?>.unmodifiable(lineItemIds),
    );
  }

  @override
  Future<GroupExpense> createExpense({
    required String groupId,
    required CreateGroupExpenseRequest request,
    required String idempotencyKey,
  }) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    _requireCurrentUserMembership(group);
    _validateIdempotencyKey(idempotencyKey);
    _validateCommonExpenseRequest(group, request);

    final fingerprint = jsonEncode(<String, Object?>{
      'group_id': groupId,
      ...request.toJson(),
    });
    final existing = _expenseRequests[idempotencyKey];
    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        throw _idempotencyConflict();
      }
      return GroupExpense.fromJson(existing.value.toJson());
    }

    final expenseId = _newExpenseId();
    final split = _buildSplitResult(
      group: group,
      request: request,
      expenseId: expenseId,
    );
    final timestamp = _timestamp();
    final stored = GroupExpense(
      id: expenseId,
      groupId: groupId,
      receiptId: request.receiptId,
      payerUserId: request.payerUserId,
      createdBy: currentUserId,
      title: request.title.trim(),
      note: request.note,
      expenseDate: request.expenseDate,
      totalAmountInMinor: request.totalAmountInMinor,
      currency: request.currency,
      splitType: request.split.type,
      isFinanciallyLocked: false,
      shares: split.shares,
      lineItemAssignments: split.lineItemAssignments,
      createdAt: timestamp,
      updatedAt: timestamp,
      deletedAt: null,
    );
    _expensesByGroup.putIfAbsent(groupId, () => <GroupExpense>[]).add(stored);
    _expenseRequests[idempotencyKey] = _IdempotentValue<GroupExpense>(
      fingerprint: fingerprint,
      value: stored,
    );
    return GroupExpense.fromJson(stored.toJson());
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

  void _validateCommonExpenseRequest(
    GroupDetail group,
    CreateGroupExpenseRequest request,
  ) {
    if (request.title.trim().isEmpty ||
        request.totalAmountInMinor <= 0 ||
        request.currency != group.currency ||
        !_isActiveMember(group, request.payerUserId) ||
        DateTime.tryParse(request.expenseDate)?.isUtc != true) {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Masraf bilgileri geçersiz.',
      );
    }
    if (request.split.type == SplitType.itemized && request.receiptId == null) {
      throw _apiException(
        statusCode: 409,
        code: 'receipt_not_synced',
        message: 'Fiş buluta senkronize edilmeden kalem bazlı bölüştürülemez.',
      );
    }
    if (request.receiptId case final receiptId?) {
      if (!_preparedReceiptLineAmounts.containsKey(receiptId)) {
        throw _apiException(
          statusCode: 409,
          code: 'receipt_not_synced',
          message: 'Fiş buluta senkronize edilmemiş.',
        );
      }
    }
  }

  _BuiltSplitResult _buildSplitResult({
    required GroupDetail group,
    required CreateGroupExpenseRequest request,
    required String expenseId,
  }) {
    final names = <String, String>{
      for (final member in group.members)
        if (member.leftAt == null) member.userId: member.displayName,
    };
    final amountsByUser = <String, int>{};
    final assignments = <ReceiptLineItemAssignment>[];

    void addAmount(String userId, int amountInMinor) {
      if (!names.containsKey(userId) || amountInMinor < 0) {
        throw _invalidSplitTotal();
      }
      amountsByUser[userId] = (amountsByUser[userId] ?? 0) + amountInMinor;
    }

    switch (request.split) {
      case EqualSplitRequest(:final memberIds):
        _validateUniqueMembers(group, memberIds);
        final amounts = splitEqualInMinor(
          request.totalAmountInMinor,
          memberIds.length,
        );
        for (var index = 0; index < memberIds.length; index++) {
          addAmount(memberIds[index], amounts[index]);
        }
      case PercentageSplitRequest(:final shares):
        _validateUniqueMembers(
          group,
          shares.map((share) => share.userId).toList(growable: false),
        );
        final basisPoints = shares
            .map((share) => share.percentageBasisPoints)
            .toList(growable: false);
        if (basisPoints.fold<int>(0, (sum, value) => sum + value) != 10000) {
          throw _apiException(
            statusCode: 422,
            code: 'invalid_percentage_total',
            message: 'Yüzde toplamı 10000 basis point olmalıdır.',
          );
        }
        final amounts = splitByBasisPointsInMinor(
          request.totalAmountInMinor,
          basisPoints,
        );
        for (var index = 0; index < shares.length; index++) {
          addAmount(shares[index].userId, amounts[index]);
        }
      case FixedAmountSplitRequest(:final shares):
        _validateUniqueMembers(
          group,
          shares.map((share) => share.userId).toList(growable: false),
        );
        for (final share in shares) {
          addAmount(share.userId, share.amountInMinor);
        }
      case ItemizedSplitRequest(:final lineItems, :final extraAmountShares):
        final receiptId = request.receiptId!;
        final preparedLines = _preparedReceiptLineAmounts[receiptId];
        if (preparedLines == null) {
          throw _apiException(
            statusCode: 409,
            code: 'receipt_not_synced',
            message: 'Fiş buluta senkronize edilmemiş.',
          );
        }
        final requestedLineIds = lineItems
            .map((item) => item.receiptLineItemId)
            .toSet();
        final unassignedLineIds = preparedLines.keys
            .where((lineId) => !requestedLineIds.contains(lineId))
            .toList(growable: false);
        if (unassignedLineIds.isNotEmpty ||
            requestedLineIds.length != lineItems.length) {
          throw GroupApiException(
            statusCode: 422,
            error: GroupApiError(
              detail: GroupApiErrorDetail(
                code: 'unassigned_line_items',
                message: 'Atanmayan ürünler bulunuyor.',
                unassignedReceiptLineItemIds: unassignedLineIds,
              ),
            ),
          );
        }
        for (final lineItem in lineItems) {
          final expectedAmount = preparedLines[lineItem.receiptLineItemId];
          if (expectedAmount == null || lineItem.shares.isEmpty) {
            throw _invalidSplitTotal();
          }
          var lineTotal = 0;
          for (final share in lineItem.shares) {
            addAmount(share.userId, share.amountInMinor);
            lineTotal += share.amountInMinor;
            assignments.add(
              ReceiptLineItemAssignment(
                expenseId: expenseId,
                receiptLineItemId: lineItem.receiptLineItemId,
                userId: share.userId,
                amountInMinor: share.amountInMinor,
                quantityShareMilli: share.quantityShareMilli,
              ),
            );
          }
          if (lineTotal != expectedAmount) throw _invalidSplitTotal();
        }
        for (final share in extraAmountShares) {
          addAmount(share.userId, share.amountInMinor);
        }
    }

    final total = amountsByUser.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );
    if (amountsByUser.isEmpty || total != request.totalAmountInMinor) {
      throw _invalidSplitTotal();
    }
    return _BuiltSplitResult(
      shares: amountsByUser.entries
          .map(
            (entry) => ExpenseShare(
              expenseId: expenseId,
              userId: entry.key,
              displayName: names[entry.key]!,
              amountInMinor: entry.value,
              status: ShareStatus.open,
              settledAt: null,
            ),
          )
          .toList(growable: false),
      lineItemAssignments: assignments,
    );
  }

  void _validateUniqueMembers(GroupDetail group, List<String> memberIds) {
    if (memberIds.isEmpty ||
        memberIds.toSet().length != memberIds.length ||
        memberIds.any((userId) => !_isActiveMember(group, userId))) {
      throw _invalidSplitTotal();
    }
  }

  GroupApiException _invalidSplitTotal() => _apiException(
    statusCode: 422,
    code: 'invalid_split_total',
    message: 'Payların toplamı masraf toplamına eşit olmalıdır.',
  );

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

  String _newReceiptId() => _nextUuid('20000000', _nextReceiptSequence++);

  String _newReceiptLineItemId() =>
      _nextUuid('30000000', _nextReceiptLineSequence++);

  String _newExpenseId() => _nextUuid('40000000', _nextExpenseSequence++);

  String _nextUuid(String prefix, int sequence) =>
      '$prefix-0000-4000-8000-${sequence.toString().padLeft(12, '0')}';
}

class _BuiltSplitResult {
  const _BuiltSplitResult({
    required this.shares,
    required this.lineItemAssignments,
  });

  final List<ExpenseShare> shares;
  final List<ReceiptLineItemAssignment> lineItemAssignments;
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

FakeGroupRepository _createDefaultFakeGroupRepository() {
  return FakeGroupRepository(
    currentUserId: currentUserId,
    currentUserDisplayName: 'Zafer Tuna',
    latency: const Duration(milliseconds: 250),
    groups: const [twoMemberGroup, fourMemberGroup],
    expensesByGroup: const {
      twoMemberGroupId: [fastSplitTransferExpense, itemizedMarketExpense],
    },
    debtSummariesByGroup: const {
      twoMemberGroupId: currentUserCreditorDebtSummary,
    },
    settlementsByGroup: const {
      twoMemberGroupId: [sampleSettlement],
    },
  );
}
