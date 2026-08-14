import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_providers.dart';
import '../data/group_repository.dart';
import '../domain/group_expense_draft.dart';
import '../domain/group_models.dart';
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
      return GroupExpenseFlowController(
        ref.watch(groupExpenseRepositoryProvider),
      );
    });

class GroupExpenseFlowController extends StateNotifier<GroupExpenseFlowState> {
  GroupExpenseFlowController(this._repository)
    : super(const GroupExpenseFlowState.idle());

  final GroupExpenseRepository _repository;

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
      final expense = await _repository.createFastSplit(
        FastSplitExpenseRequest(
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
        ),
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
      final expense = await _repository.createItemizedSplit(
        ItemizedExpenseRequest(
          groupId: draft.groupId,
          receiptId: receiptId,
          title: _requireTitle(draft),
          payerUserId: _requirePayer(snapshot),
          expenseDate: _requireDate(draft),
          totalAmountInMinor: _requireAmount(draft),
          currency: draft.currency,
          lineShares: snapshot.itemizedLineShares,
          extraShares: snapshot.extraAmountShares,
        ),
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
