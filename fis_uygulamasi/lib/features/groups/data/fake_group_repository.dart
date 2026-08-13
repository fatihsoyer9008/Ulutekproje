import 'dart:convert';

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
  int _nextExpenseSequence = 1;

  @override
  Future<GroupsResponse> listGroups({bool includeArchived = false}) async {
    await _beforeRequest();
    final groups = _groupsById.values
        .where(_hasCurrentUserMembership)
        .where((group) => includeArchived || group.archivedAt == null)
        .map(
          (group) => Group.fromJson({
            ...group.toJson(),
            'current_user_role': _currentUserRole(group)!.name,
          }),
        )
        .toList(growable: false);
    return GroupsResponse(groups: groups);
  }

  @override
  Future<GroupDetail> getGroup(String groupId) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    _requireCurrentUserMembership(group);
    return group.copyWith(currentUserRole: _currentUserRole(group)!);
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
  Future<void> createInvitation({
    required String groupId,
    required String email,
    GroupRole role = GroupRole.member,
  }) async {
    await _beforeRequest();

    final group = _requireGroup(groupId);
    final currentRole = _currentUserRole(group);
    final normalizedEmail = email.trim().toLowerCase();
    final emailIsValid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(normalizedEmail);

    if (!emailIsValid || role == GroupRole.owner) {
      throw _apiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Geçerli bir e-posta adresi ve rol seçin.',
      );
    }

    if (currentRole != GroupRole.owner && currentRole != GroupRole.admin) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Bu gruba davet gönderme yetkiniz yok.',
      );
    }

    if (currentRole == GroupRole.admin && role != GroupRole.member) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Admin yalnızca üye rolünde davet gönderebilir.',
      );
    }

    // Production davranışı: davet kabul edilmeden üyelik oluşmaz.
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
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _beforeRequest();
    final group = _requireGroup(groupId);
    final currentRole = _currentUserRole(group);

    if (currentRole != GroupRole.owner && currentRole != GroupRole.admin) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Bu gruptan üye çıkarma yetkiniz yok.',
      );
    }

    final member = group.members
        .where((item) => item.userId == userId && item.leftAt == null)
        .firstOrNull;

    if (member == null) {
      throw _apiException(
        statusCode: 404,
        code: 'member_not_found',
        message: 'Aktif grup üyesi bulunamadı.',
      );
    }

    if (member.userId == currentUserId) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Kendinizi bu ekrandan gruptan çıkaramazsınız.',
      );
    }

    if (member.role == GroupRole.owner) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Grup sahibi çıkarılamaz.',
      );
    }

    if (currentRole == GroupRole.admin && member.role != GroupRole.member) {
      throw _apiException(
        statusCode: 403,
        code: 'group_forbidden',
        message: 'Admin yalnızca member rolündeki üyeleri çıkarabilir.',
      );
    }

    final timestamp = _timestamp();
    final members = [
      for (final item in group.members)
        if (item.userId == userId && item.leftAt == null)
          GroupMember.fromJson({...item.toJson(), 'left_at': timestamp})
        else
          item,
    ];

    _groupsById[groupId] = group.copyWith(
      memberCount: members.where((item) => item.leftAt == null).length,
      members: members,
      updatedAt: timestamp,
    );
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
    CreateGroupExpenseRequest request, {
    required String idempotencyKey,
  }) async {
    await _beforeRequest();

    final group = _requireGroup(request.groupId);
    _requireCurrentUserMembership(group);
    _validateIdempotencyKey(idempotencyKey);
    _validateCreateExpenseRequest(group, request);

    final fingerprint = jsonEncode(request.toJson());
    final existing = _expenseRequests[idempotencyKey];

    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        throw _idempotencyConflict();
      }
      return GroupExpense.fromJson(existing.value.toJson());
    }

    final expenseId = _newExpenseId();
    final timestamp = _timestamp();
    final shares = _createSharesForRequest(group, request, expenseId);

    final stored = GroupExpense(
      id: expenseId,
      groupId: request.groupId,
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
      shares: shares,
      lineItemAssignments: const <ReceiptLineItemAssignment>[],
      extraAmounts: const <ExpenseExtraAmount>[],
      createdAt: timestamp,
      updatedAt: timestamp,
      deletedAt: null,
    );

    _validateExpense(group, stored);

    _expensesByGroup
        .putIfAbsent(request.groupId, () => <GroupExpense>[])
        .add(stored);

    _applyExpenseToDebtSummary(group, stored);

    _expenseRequests[idempotencyKey] = _IdempotentValue<GroupExpense>(
      fingerprint: fingerprint,
      value: stored,
    );

    return GroupExpense.fromJson(stored.toJson());
  }

  List<ExpenseShare> _createSharesForRequest(
    GroupDetail group,
    CreateGroupExpenseRequest request,
    String expenseId,
  ) {
    final memberNames = <String, String>{
      for (final member in group.members)
        if (member.leftAt == null) member.userId: member.displayName,
    };

    ExpenseShare shareFor(String userId, int amountInMinor) {
      return ExpenseShare(
        expenseId: expenseId,
        userId: userId,
        displayName: memberNames[userId] ?? 'Grup üyesi',
        amountInMinor: amountInMinor,
        status: ShareStatus.open,
        settledAt: null,
      );
    }

    return switch (request.split.type) {
      SplitType.equal => _createEqualShares(
        request.split.memberIds,
        request.totalAmountInMinor,
        shareFor,
      ),
      SplitType.percentage => _createPercentageShares(
        request.split.shares,
        request.totalAmountInMinor,
        shareFor,
      ),
      SplitType.fixedAmount => [
        for (final share in request.split.shares)
          shareFor(share.userId, share.amountInMinor!),
      ],
      SplitType.itemized => throw StateError(
        'Fast Split itemized bölüştürmeyi desteklemez.',
      ),
    };
  }

  List<ExpenseShare> _createEqualShares(
    List<String> memberIds,
    int totalAmountInMinor,
    ExpenseShare Function(String userId, int amountInMinor) shareFor,
  ) {
    final baseAmount = totalAmountInMinor ~/ memberIds.length;
    var remainingMinor = totalAmountInMinor % memberIds.length;

    return [
      for (final userId in memberIds)
        shareFor(userId, baseAmount + (remainingMinor-- > 0 ? 1 : 0)),
    ];
  }

  List<ExpenseShare> _createPercentageShares(
    List<ExpenseSplitShareRequest> requestShares,
    int totalAmountInMinor,
    ExpenseShare Function(String userId, int amountInMinor) shareFor,
  ) {
    var assignedAmount = 0;
    final shares = <ExpenseShare>[];

    for (var index = 0; index < requestShares.length; index++) {
      final requestShare = requestShares[index];

      final amountInMinor = index == requestShares.length - 1
          ? totalAmountInMinor - assignedAmount
          : totalAmountInMinor * requestShare.percentageBasisPoints! ~/ 10000;

      assignedAmount += amountInMinor;
      shares.add(shareFor(requestShare.userId, amountInMinor));
    }

    return shares;
  }

  void _validateCreateExpenseRequest(
    GroupDetail group,
    CreateGroupExpenseRequest request,
  ) {
    final split = request.split;

    final hasInvalidCommonFields =
        request.title.trim().isEmpty ||
        request.totalAmountInMinor <= 0 ||
        request.currency != group.currency ||
        !_isActiveMember(group, request.payerUserId);

    final splitIsValid = switch (split.type) {
      SplitType.equal =>
        split.memberIds.isNotEmpty &&
            split.memberIds.toSet().length == split.memberIds.length &&
            split.memberIds.every((userId) => _isActiveMember(group, userId)),
      SplitType.percentage =>
        split.shares.isNotEmpty &&
            split.shares.every(
              (share) =>
                  share.percentageBasisPoints != null &&
                  share.percentageBasisPoints! >= 0 &&
                  _isActiveMember(group, share.userId),
            ) &&
            split.shares.map((share) => share.userId).toSet().length ==
                split.shares.length &&
            split.shares.fold<int>(
                  0,
                  (total, share) => total + share.percentageBasisPoints!,
                ) ==
                10000,
      SplitType.fixedAmount =>
        split.shares.isNotEmpty &&
            split.shares.every(
              (share) =>
                  share.amountInMinor != null &&
                  share.amountInMinor! >= 0 &&
                  _isActiveMember(group, share.userId),
            ) &&
            split.shares.map((share) => share.userId).toSet().length ==
                split.shares.length &&
            split.shares.fold<int>(
                  0,
                  (total, share) => total + share.amountInMinor!,
                ) ==
                request.totalAmountInMinor,
      SplitType.itemized => false,
    };

    if (hasInvalidCommonFields || !splitIsValid) {
      throw _apiException(
        statusCode: 422,
        code: 'invalid_split_total',
        message: 'Masraf veya bölüştürme bilgileri geçersiz.',
      );
    }
  }

  void _applyExpenseToDebtSummary(GroupDetail group, GroupExpense expense) {
    final existingSummary = _debtSummariesByGroup[group.id];

    final balancesByUserId = <String, DebtBalance>{
      for (final member in group.members)
        if (member.leftAt == null)
          member.userId: DebtBalance(
            userId: member.userId,
            displayName: member.displayName,
            netAmountInMinor: 0,
          ),
    };

    if (existingSummary != null) {
      for (final balance in existingSummary.balances) {
        balancesByUserId[balance.userId] = balance;
      }
    }

    void changeBalance(String userId, int amountInMinor) {
      final previous = balancesByUserId[userId];
      if (previous == null) return;

      balancesByUserId[userId] = DebtBalance(
        userId: previous.userId,
        displayName: previous.displayName,
        netAmountInMinor: previous.netAmountInMinor + amountInMinor,
      );
    }

    // Ödeyen kişi masraf kadar alacaklı olur.
    changeBalance(expense.payerUserId, expense.totalAmountInMinor);

    // Katılımcıların her biri kendi payı kadar borçlanır.
    for (final share in expense.shares) {
      changeBalance(share.userId, -share.amountInMinor);
    }

    final balances = balancesByUserId.values.toList(growable: false);

    final remainingDebts = <String, int>{
      for (final balance in balances)
        if (balance.netAmountInMinor < 0)
          balance.userId: -balance.netAmountInMinor,
    };

    final remainingCredits = <String, int>{
      for (final balance in balances)
        if (balance.netAmountInMinor > 0)
          balance.userId: balance.netAmountInMinor,
    };

    final transfers = <DebtTransfer>[];
    final debtorIds = remainingDebts.keys.toList();
    final creditorIds = remainingCredits.keys.toList();

    var debtorIndex = 0;
    var creditorIndex = 0;

    while (debtorIndex < debtorIds.length &&
        creditorIndex < creditorIds.length) {
      final debtorId = debtorIds[debtorIndex];
      final creditorId = creditorIds[creditorIndex];
      final debt = remainingDebts[debtorId]!;
      final credit = remainingCredits[creditorId]!;
      final amount = debt < credit ? debt : credit;

      transfers.add(
        DebtTransfer(
          fromUserId: debtorId,
          toUserId: creditorId,
          amountInMinor: amount,
        ),
      );

      remainingDebts[debtorId] = debt - amount;
      remainingCredits[creditorId] = credit - amount;

      if (remainingDebts[debtorId] == 0) {
        debtorIndex++;
      }

      if (remainingCredits[creditorId] == 0) {
        creditorIndex++;
      }
    }

    _debtSummariesByGroup[group.id] = DebtSummary(
      groupId: group.id,
      currency: group.currency,
      balances: balances,
      suggestedTransfers: transfers,
      generatedAt: _timestamp(),
    );
  }

  @override
  Future<GroupExpense> createFastSplit(
    FastSplitExpenseRequest request, {
    required String idempotencyKey,
  }) {
    final split = switch (request.splitType) {
      SplitType.equal => ExpenseSplitRequest.equal(
        memberIds: request.orderedMemberIds,
      ),
      SplitType.percentage => ExpenseSplitRequest.percentage(
        shares: [
          for (final userId in request.orderedMemberIds)
            ExpenseSplitShareRequest.percentage(
              userId: userId,
              percentageBasisPoints: request.percentageBasisPoints[userId] ?? 0,
            ),
        ],
      ),
      SplitType.fixedAmount => ExpenseSplitRequest.fixedAmount(
        shares: [
          for (final userId in request.orderedMemberIds)
            ExpenseSplitShareRequest.fixedAmount(
              userId: userId,
              amountInMinor: request.fixedAmountsInMinor[userId] ?? 0,
            ),
        ],
      ),
      SplitType.itemized => throw ArgumentError.value(
        request.splitType,
        'splitType',
        'Kalem bazlı bölüştürme createItemizedSplit ile oluşturulmalıdır.',
      ),
    };

    return createExpense(
      CreateGroupExpenseRequest(
        groupId: request.groupId,
        receiptId: null,
        payerUserId: request.payerUserId,
        title: request.title,
        note: null,
        expenseDate: request.expenseDate,
        totalAmountInMinor: request.totalAmountInMinor,
        currency: request.currency,
        split: split,
      ),
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<GroupExpense> createItemizedSplit(
    ItemizedExpenseRequest request, {
    required String idempotencyKey,
  }) async {
    await _beforeRequest();
    final group = _requireGroup(request.groupId);
    _requireCurrentUserMembership(group);
    _validateIdempotencyKey(idempotencyKey);

    final fingerprint = jsonEncode(<String, Object?>{
      'type': 'itemized',
      'group_id': request.groupId,
      'receipt_id': request.receiptId,
      'title': request.title,
      'payer_user_id': request.payerUserId,
      'expense_date': request.expenseDate,
      'total_amount_in_minor': request.totalAmountInMinor,
      'currency': request.currency,
      'line_shares': [
        for (final share in request.lineShares)
          <String, Object?>{
            'receipt_line_item_id': share.receiptLineItemId,
            'user_id': share.userId,
            'amount_in_minor': share.amountInMinor,
            'quantity_share_milli': share.quantityShareMilli,
          },
      ],
      'extra_shares': [
        for (final share in request.extraShares)
          <String, Object?>{
            'user_id': share.userId,
            'amount_in_minor': share.amountInMinor,
          },
      ],
    });
    final existing = _expenseRequests[idempotencyKey];
    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        throw _idempotencyConflict();
      }
      return GroupExpense.fromJson(existing.value.toJson());
    }

    final now = _timestamp();
    final expenseId = _newExpenseId();
    final extraAmountId = '$expenseId-extra-1';
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
    final stored = GroupExpense(
      id: expenseId,
      groupId: request.groupId,
      receiptId: request.receiptId,
      payerUserId: request.payerUserId,
      createdBy: currentUserId,
      title: request.title.trim(),
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
    );

    if (request.title.trim().isEmpty || request.receiptId.trim().isEmpty) {
      throw _apiException(
        statusCode: 422,
        code: 'invalid_split_total',
        message: 'Masraf veya bölüştürme bilgileri geçersiz.',
      );
    }
    _validateExpense(group, stored);
    _expensesByGroup
        .putIfAbsent(request.groupId, () => <GroupExpense>[])
        .add(stored);
    _applyExpenseToDebtSummary(group, stored);
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
    _applySettlementToDebtSummary(stored);
    _settlementRequests[idempotencyKey] = _IdempotentValue<Settlement>(
      fingerprint: fingerprint,
      value: stored,
    );
    return Settlement.fromJson(stored.toJson());
  }

  void _applySettlementToDebtSummary(Settlement settlement) {
    final summary = _debtSummariesByGroup[settlement.groupId];
    if (summary == null) return;

    final balances = summary.balances
        .map(
          (balance) => DebtBalance(
            userId: balance.userId,
            displayName: balance.displayName,
            netAmountInMinor:
                balance.netAmountInMinor +
                (balance.userId == settlement.fromUserId
                    ? settlement.amountInMinor
                    : balance.userId == settlement.toUserId
                    ? -settlement.amountInMinor
                    : 0),
          ),
        )
        .toList(growable: false);

    var remainingPayment = settlement.amountInMinor;
    final transfers = <DebtTransfer>[];

    for (final transfer in summary.suggestedTransfers) {
      final isMatchingTransfer =
          transfer.fromUserId == settlement.fromUserId &&
          transfer.toUserId == settlement.toUserId;

      if (!isMatchingTransfer || remainingPayment == 0) {
        transfers.add(transfer);
        continue;
      }

      final paidAmount = transfer.amountInMinor < remainingPayment
          ? transfer.amountInMinor
          : remainingPayment;

      remainingPayment -= paidAmount;

      final remainingTransferAmount = transfer.amountInMinor - paidAmount;
      if (remainingTransferAmount > 0) {
        transfers.add(
          DebtTransfer(
            fromUserId: transfer.fromUserId,
            toUserId: transfer.toUserId,
            amountInMinor: remainingTransferAmount,
          ),
        );
      }
    }

    _debtSummariesByGroup[settlement.groupId] = DebtSummary(
      groupId: summary.groupId,
      currency: summary.currency,
      balances: balances,
      suggestedTransfers: transfers,
      generatedAt: _timestamp(),
    );
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

  String _newExpenseId() {
    while (true) {
      final suffix = _nextExpenseSequence.toString().padLeft(12, '0');
      _nextExpenseSequence += 1;
      final candidate = '40000000-0000-4000-8000-$suffix';
      final alreadyExists = _expensesByGroup.values.any(
        (expenses) => expenses.any((expense) => expense.id == candidate),
      );
      if (!alreadyExists) {
        return candidate;
      }
    }
  }

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
