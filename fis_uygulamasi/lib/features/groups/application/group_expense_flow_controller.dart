// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_providers.dart';
import '../data/fake_group_repository.dart';
import '../domain/group_expense_draft.dart';
import '../domain/group_models.dart';
import '../domain/group_offline_operation.dart';
import 'offline_first_group_expense_writer.dart';
import 'fast_split_calculator.dart';
import 'itemized_split_calculator.dart';

enum GroupExpenseFlowStatus {
  idle,
  editing,
  loading,
  success,
  error,
  cancelled,
}

class GroupExpenseFlowState {
  const GroupExpenseFlowState._({
    required this.status,
    required this.group,
    required this.groupId,
    required this.activeUserId,
    required this.payerUserId,
    required this.draft,
    required this.splitType,
    required this.fastSplitSharesInMinor,
    required this.percentageBasisPoints,
    required this.fixedAmountsInMinor,
    required this.receiptId,
    required this.itemizedLineShares,
    required this.extraAmountInMinor,
    required this.extraAmountShares,
    required this.createdExpense,
    required this.error,
  });

  const GroupExpenseFlowState.idle()
    : this._(
        status: GroupExpenseFlowStatus.idle,
        groupId: null,
        group: null,
        activeUserId: null,
        payerUserId: null,
        draft: null,
        splitType: null,
        fastSplitSharesInMinor: const <String, int>{},
        percentageBasisPoints: const <String, int>{},
        fixedAmountsInMinor: const <String, int>{},
        receiptId: null,
        itemizedLineShares: const <ItemizedLineShareInput>[],
        extraAmountInMinor: null,
        extraAmountShares: const <ItemizedExtraShareInput>[],
        createdExpense: null,
        error: null,
      );

  static const Object _unset = Object();

  final GroupExpenseFlowStatus status;
  final String? groupId;
  final GroupDetail? group;
  final String? activeUserId;
  final String? payerUserId;
  final GroupExpenseDraft? draft;
  final SplitType? splitType;

  /// Fast Split hesaplayıcısından gelen, kuruş cinsinden paylar.
  final Map<String, int> fastSplitSharesInMinor;
  final Map<String, int> percentageBasisPoints;
  final Map<String, int> fixedAmountsInMinor;

  final String? receiptId;

  /// Itemized Split hesaplayıcısından gelen ürün/pay atamaları.
  final List<ItemizedLineShareInput> itemizedLineShares;
  final int? extraAmountInMinor;
  final List<ItemizedExtraShareInput> extraAmountShares;

  final GroupExpense? createdExpense;
  final Object? error;

  bool get isSubmitting => status == GroupExpenseFlowStatus.loading;

  /// Mevcut Fast/Itemized Split sonuçlarından aktif kullanıcının payını
  /// döndürür; yeni bir finans hesaplaması yapmaz.
  int? get currentUserShareInMinor {
    final userId = activeUserId;
    if (userId == null || splitType == null) return null;

    if (splitType != SplitType.itemized) {
      return fastSplitSharesInMinor[userId] ?? 0;
    }

    final lineItemTotal = itemizedLineShares
        .where((share) => share.userId == userId)
        .fold<int>(0, (total, share) => total + share.amountInMinor);

    final extraAmountTotal = extraAmountShares
        .where((share) => share.userId == userId)
        .fold<int>(0, (total, share) => total + share.amountInMinor);

    return lineItemTotal + extraAmountTotal;
  }

  /// Mevcut Fast/Itemized Split hesaplama sonuçlarından aktif kullanıcının
  /// payını döndürür; yeni bir finansal hesaplama yapmaz.

  GroupExpenseFlowState copyWith({
    GroupExpenseFlowStatus? status,
    GroupExpenseDraft? draft,
    String? payerUserId,
    SplitType? splitType,
    Map<String, int>? fastSplitSharesInMinor,
    Map<String, int>? percentageBasisPoints,
    Map<String, int>? fixedAmountsInMinor,
    String? receiptId,
    List<ItemizedLineShareInput>? itemizedLineShares,
    int? extraAmountInMinor,
    List<ItemizedExtraShareInput>? extraAmountShares,
    Object? createdExpense = _unset,
    Object? error = _unset,
  }) {
    return GroupExpenseFlowState._(
      status: status ?? this.status,
      groupId: groupId,
      group: group,
      activeUserId: activeUserId,
      payerUserId: payerUserId ?? this.payerUserId,
      draft: draft ?? this.draft,
      splitType: splitType ?? this.splitType,
      fastSplitSharesInMinor: Map.unmodifiable(
        fastSplitSharesInMinor ?? this.fastSplitSharesInMinor,
      ),
      percentageBasisPoints: Map.unmodifiable(
        percentageBasisPoints ?? this.percentageBasisPoints,
      ),
      fixedAmountsInMinor: Map.unmodifiable(
        fixedAmountsInMinor ?? this.fixedAmountsInMinor,
      ),
      receiptId: receiptId ?? this.receiptId,
      itemizedLineShares: List.unmodifiable(
        itemizedLineShares ?? this.itemizedLineShares,
      ),
      extraAmountInMinor: extraAmountInMinor ?? this.extraAmountInMinor,
      extraAmountShares: List.unmodifiable(
        extraAmountShares ?? this.extraAmountShares,
      ),
      createdExpense: identical(createdExpense, _unset)
          ? this.createdExpense
          : createdExpense as GroupExpense?,
      error: identical(error, _unset) ? this.error : error,
    );
  }
}

final groupExpenseFlowControllerProvider =
    StateNotifierProvider.autoDispose<
      GroupExpenseFlowController,
      GroupExpenseFlowState
    >((ref) {
      final repository = ref.watch(groupExpenseRepositoryProvider);
      if (repository is FakeGroupRepository) {
        return GroupExpenseFlowController(repository);
      }
      return GroupExpenseFlowController(
        repository,
        offlineWriter: ref.watch(offlineFirstGroupExpenseWriterProvider),
        ownerKey: ref.watch(currentGroupUserIdProvider) == null
            ? null
            : 'user:${ref.watch(currentGroupUserIdProvider)}',
      );
    });

class GroupExpenseFlowController extends StateNotifier<GroupExpenseFlowState> {
  GroupExpenseFlowController(
    this._repository, {
    OfflineFirstGroupExpenseWriter? offlineWriter,
    String? ownerKey,
  }) : _offlineWriter = offlineWriter,
       _ownerKey = ownerKey,
       super(const GroupExpenseFlowState.idle());

  final GroupExpenseRepository _repository;
  final OfflineFirstGroupExpenseWriter? _offlineWriter;
  final String? _ownerKey;

  void start({
    required GroupDetail group,
    required String activeUserId,
    required GroupExpenseDraft draft,
  }) {
    if (draft.groupId != group.id) {
      throw ArgumentError.value(
        draft.groupId,
        'draft.groupId',
        'Seçili grupla eşleşmelidir.',
      );
    }

    state = GroupExpenseFlowState._(
      status: GroupExpenseFlowStatus.editing,
      groupId: group.id,
      group: group,
      activeUserId: activeUserId,
      payerUserId: draft.payerUserId,
      draft: draft,
      splitType: null,
      fastSplitSharesInMinor: const <String, int>{},
      percentageBasisPoints: const <String, int>{},
      fixedAmountsInMinor: const <String, int>{},
      receiptId: null,
      itemizedLineShares: const <ItemizedLineShareInput>[],
      extraAmountInMinor: null,
      extraAmountShares: const <ItemizedExtraShareInput>[],

      createdExpense: null,
      error: null,
    );
  }

  void updateDraft(GroupExpenseDraft draft) {
    _requireStarted();
    if (draft.groupId != state.group!.id) {
      throw ArgumentError.value(
        draft.groupId,
        'draft.groupId',
        'Seçili grupla eşleşmelidir.',
      );
    }
    state = state.copyWith(
      status: GroupExpenseFlowStatus.editing,
      draft: draft,
      error: null,
    );
  }

  void updatePayerUserId(String payerUserId) {
    _requireStarted();
    if (payerUserId.trim().isEmpty) {
      throw ArgumentError.value(payerUserId, 'payerUserId', 'Boş olamaz.');
    }
    state = state.copyWith(
      status: GroupExpenseFlowStatus.editing,
      payerUserId: payerUserId.trim(),
      error: null,
    );
  }

  /// Hesaplama FastSplitCalculator tarafından yapılır; controller tekrar hesaplamaz.
  void setFastSplit(
    FastSplitCalculation calculation, {
    Map<String, int> percentageBasisPoints = const <String, int>{},
  }) {
    _requireStarted();

    state = state.copyWith(
      status: GroupExpenseFlowStatus.editing,
      splitType: calculation.type,
      fastSplitSharesInMinor: <String, int>{
        for (final share in calculation.shares)
          share.userId: share.amountInMinor,
      },
      percentageBasisPoints: percentageBasisPoints,
      fixedAmountsInMinor: <String, int>{
        for (final share in calculation.shares)
          share.userId: share.amountInMinor,
      },
      error: null,
    );
  }

  /// Hesaplama ItemizedSplitCalculator tarafından yapılır; controller tekrar hesaplamaz.
  void setItemizedSplit({
    required String receiptId,
    required ItemizedSplitCalculation calculation,
  }) {
    _requireStarted();
    if (receiptId.trim().isEmpty) {
      throw ArgumentError.value(receiptId, 'receiptId', 'Boş olamaz.');
    }

    state = state.copyWith(
      status: GroupExpenseFlowStatus.editing,
      splitType: SplitType.itemized,
      receiptId: receiptId.trim(),
      itemizedLineShares: [
        for (final share in calculation.lineItemShares)
          ItemizedLineShareInput(
            receiptLineItemId: share.receiptLineItemId,
            userId: share.userId,
            amountInMinor: share.amountInMinor,
            quantityShareMilli: share.quantityShareMilli,
          ),
      ],
      extraAmountInMinor: calculation.extraAmountInMinor,
      extraAmountShares: [
        for (final share in calculation.extraAmountShares)
          ItemizedExtraShareInput(
            userId: share.userId,
            amountInMinor: share.amountInMinor,
          ),
      ],
      error: null,
    );
  }

  Future<void> submitFastSplit({required String idempotencyKey}) async {
    if (state.isSubmitting) return;

    final snapshot = state;
    final draft = _requireDraft(snapshot);
    final splitType = snapshot.splitType;
    if (splitType == null || splitType == SplitType.itemized) {
      throw StateError('Fast Split türü seçilmelidir.');
    }

    final orderedMemberIds = snapshot.fastSplitSharesInMinor.keys.toList();
    if (orderedMemberIds.isEmpty) {
      throw StateError('En az bir Fast Split payı olmalıdır.');
    }

    state = snapshot.copyWith(
      status: GroupExpenseFlowStatus.loading,
      error: null,
    );

    try {
      final request = FastSplitExpenseRequest(
        groupId: draft.groupId,
        title: _requireTitle(draft),
        payerUserId: _requirePayer(snapshot),
        expenseDate: _requireDate(draft),
        totalAmountInMinor: _requireAmount(draft),
        currency: draft.currency,
        splitType: splitType,
        orderedMemberIds: orderedMemberIds,
        percentageBasisPoints: snapshot.percentageBasisPoints,
        fixedAmountsInMinor: snapshot.fixedAmountsInMinor,
      );
      final expense = _offlineWriter != null && _ownerKey != null
          ? await _queueFastSplit(request, idempotencyKey)
          : await _repository.createFastSplit(
              request,
              idempotencyKey: idempotencyKey,
            );

      state = snapshot.copyWith(
        status: GroupExpenseFlowStatus.success,
        createdExpense: expense,
        error: null,
      );
    } catch (error) {
      // snapshot kullanıldığı için taslak ve bütün paylar korunur.
      state = snapshot.copyWith(
        status: GroupExpenseFlowStatus.error,
        error: error,
      );
    }
  }

  Future<void> submitItemizedSplit({required String idempotencyKey}) async {
    if (state.isSubmitting) return;

    final snapshot = state;
    final draft = _requireDraft(snapshot);
    final receiptId = snapshot.receiptId;
    if (snapshot.splitType != SplitType.itemized ||
        receiptId == null ||
        receiptId.isEmpty) {
      throw StateError('Kalem bazlı bölüştürme hazırlanmalıdır.');
    }

    state = snapshot.copyWith(
      status: GroupExpenseFlowStatus.loading,
      error: null,
    );

    try {
      final request = ItemizedExpenseRequest(
        groupId: draft.groupId,
        receiptId: receiptId,
        title: _requireTitle(draft),
        payerUserId: _requirePayer(snapshot),
        expenseDate: _requireDate(draft),
        totalAmountInMinor: _requireAmount(draft),
        currency: draft.currency,
        lineShares: snapshot.itemizedLineShares,
        extraShares: snapshot.extraAmountShares,
      );
      final expense = _offlineWriter != null && _ownerKey != null
          ? await _queueItemizedSplit(request, idempotencyKey)
          : await _repository.createItemizedSplit(
              request,
              idempotencyKey: idempotencyKey,
            );

      state = snapshot.copyWith(
        status: GroupExpenseFlowStatus.success,
        createdExpense: expense,
        error: null,
      );
    } catch (error) {
      state = snapshot.copyWith(
        status: GroupExpenseFlowStatus.error,
        error: error,
      );
    }
  }

  void cancel() {
    if (state.status == GroupExpenseFlowStatus.idle) return;
    state = state.copyWith(
      status: GroupExpenseFlowStatus.cancelled,
      error: null,
    );
  }

  Future<GroupExpense> _queueFastSplit(
    FastSplitExpenseRequest request,
    String clientRecordId,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final shares = <ExpenseShare>[
      for (final userId in request.orderedMemberIds)
        ExpenseShare(
          expenseId: clientRecordId,
          userId: userId,
          displayName: _memberName(userId),
          amountInMinor: state.fastSplitSharesInMinor[userId] ?? 0,
          status: ShareStatus.open,
          settledAt: null,
        ),
    ];
    final expense = GroupExpense(
      id: clientRecordId,
      groupId: request.groupId,
      receiptId: null,
      payerUserId: request.payerUserId,
      createdBy: state.activeUserId,
      title: request.title,
      note: null,
      expenseDate: request.expenseDate,
      totalAmountInMinor: request.totalAmountInMinor,
      currency: request.currency,
      splitType: request.splitType,
      isFinanciallyLocked: false,
      shares: shares,
      lineItemAssignments: const [],
      extraAmounts: const [],
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _offlineWriter!.save(
      GroupExpenseOfflineOperation.create(
        expense: expense,
        clientRecordId: clientRecordId,
        ownerKey: _ownerKey!,
        syncPayload: _fastSyncPayload(request),
      ),
    );
    return expense;
  }

  Future<GroupExpense> _queueItemizedSplit(
    ItemizedExpenseRequest request,
    String clientRecordId,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final expense = GroupExpense(
      id: clientRecordId,
      groupId: request.groupId,
      receiptId: request.receiptId,
      payerUserId: request.payerUserId,
      createdBy: state.activeUserId,
      title: request.title,
      note: null,
      expenseDate: request.expenseDate,
      totalAmountInMinor: request.totalAmountInMinor,
      currency: request.currency,
      splitType: SplitType.itemized,
      isFinanciallyLocked: false,
      shares: const [],
      lineItemAssignments: [
        for (final share in request.lineShares)
          if (share.receiptLineItemId != null)
            ReceiptLineItemAssignment(
              expenseId: clientRecordId,
              receiptLineItemId: share.receiptLineItemId!,
              userId: share.userId,
              amountInMinor: share.amountInMinor,
              quantityShareMilli: share.quantityShareMilli,
            ),
      ],
      extraAmounts: const [],
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _offlineWriter!.save(
      GroupExpenseOfflineOperation.create(
        expense: expense,
        clientRecordId: clientRecordId,
        ownerKey: _ownerKey!,
        syncPayload: _itemizedSyncPayload(request),
      ),
    );
    return expense;
  }

  String _memberName(String userId) =>
      state.group!.members
          .where((member) => member.userId == userId)
          .map((member) => member.displayName)
          .firstOrNull ??
      userId;

  Map<String, Object?> _fastSyncPayload(
    FastSplitExpenseRequest request,
  ) => <String, Object?>{
    'title': request.title,
    'note': null,
    'expense_date': request.expenseDate,
    'total_amount_in_minor': request.totalAmountInMinor,
    'currency': request.currency,
    'receipt_id': null,
    'payer_user_id': request.payerUserId,
    'split': switch (request.splitType) {
      SplitType.equal => {
        'type': 'equal',
        'member_ids': request.orderedMemberIds,
      },
      SplitType.percentage => {
        'type': 'percentage',
        'shares': [
          for (final id in request.orderedMemberIds)
            {
              'user_id': id,
              'percentage_basis_points': request.percentageBasisPoints[id],
            },
        ],
      },
      SplitType.fixedAmount => {
        'type': 'fixed_amount',
        'shares': [
          for (final id in request.orderedMemberIds)
            {'user_id': id, 'amount_in_minor': request.fixedAmountsInMinor[id]},
        ],
      },
      SplitType.itemized => throw StateError('Fast split itemized olamaz.'),
    },
  };

  Map<String, Object?> _itemizedSyncPayload(ItemizedExpenseRequest request) {
    final sharesByLine = <String, List<ItemizedLineShareInput>>{};
    for (final share in request.lineShares) {
      final key =
          share.receiptLineItemId ??
          'position:${share.receiptLineItemPosition}';
      (sharesByLine[key] ??= <ItemizedLineShareInput>[]).add(share);
    }
    return <String, Object?>{
      'title': request.title,
      'note': null,
      'expense_date': request.expenseDate,
      'total_amount_in_minor': request.totalAmountInMinor,
      'currency': request.currency,
      'receipt_id': request.receiptId,
      'payer_user_id': request.payerUserId,
      'split': {
        'type': 'itemized',
        'line_items': [
          for (final entry in sharesByLine.entries)
            {
              if (entry.value.first.receiptLineItemId != null)
                'receipt_line_item_id': entry.value.first.receiptLineItemId,
              if (entry.value.first.receiptLineItemPosition != null)
                'receipt_line_item_position':
                    entry.value.first.receiptLineItemPosition,
              'shares': [
                for (final share in entry.value)
                  {
                    'user_id': share.userId,
                    'amount_in_minor': share.amountInMinor,
                    'quantity_share_milli': share.quantityShareMilli,
                  },
              ],
            },
        ],
        'extra_amounts': request.extraShares.isEmpty
            ? <Object?>[]
            : [
                {
                  'type': 'other',
                  'label': 'Fiş toplam farkı',
                  'amount_in_minor': request.extraShares.fold<int>(
                    0,
                    (sum, item) => sum + item.amountInMinor,
                  ),
                  'shares': [
                    for (final share in request.extraShares)
                      {
                        'user_id': share.userId,
                        'amount_in_minor': share.amountInMinor,
                      },
                  ],
                },
              ],
      },
    };
  }

  /// UI başarı veya iptal sonucunu gördükten sonra bu metodu çağırır.
  void clear() {
    state = const GroupExpenseFlowState.idle();
  }

  void _requireStarted() {
    if (state.group == null || state.draft == null) {
      throw StateError('Masraf akışı önce başlatılmalıdır.');
    }
  }

  GroupExpenseDraft _requireDraft(GroupExpenseFlowState value) {
    final draft = value.draft;
    if (draft == null) {
      throw StateError('Masraf taslağı bulunamadı.');
    }
    return draft;
  }

  String _requirePayer(GroupExpenseFlowState value) {
    final payerUserId = value.payerUserId?.trim();
    if (payerUserId == null || payerUserId.isEmpty) {
      throw StateError('Ödeyen kullanıcı seçilmelidir.');
    }
    return payerUserId;
  }

  String _requireTitle(GroupExpenseDraft draft) {
    final title = draft.merchantName.trim();
    if (title.isEmpty) {
      throw StateError('Harcama başlığı boş olamaz.');
    }
    return title;
  }

  int _requireAmount(GroupExpenseDraft draft) {
    final amount = draft.totalAmountInMinor;
    if (amount == null || amount <= 0) {
      throw StateError('Toplam tutar sıfırdan büyük olmalıdır.');
    }
    return amount;
  }

  String _requireDate(GroupExpenseDraft draft) {
    final date = draft.expenseDate;
    if (date == null) {
      throw StateError('Harcama tarihi seçilmelidir.');
    }
    return date.toUtc().toIso8601String();
  }
}
