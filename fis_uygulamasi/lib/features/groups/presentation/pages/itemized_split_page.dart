import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/group_repository.dart';
import '../../domain/group_expense_requests.dart';
import '../../domain/group_models.dart';
import '../../domain/prepared_group_receipt.dart';
import '../../domain/split_calculator.dart';
import '../../../transaction_draft/model/turkish_money.dart';

class ItemizedSplitPage extends ConsumerStatefulWidget {
  const ItemizedSplitPage({
    required this.groupId,
    required this.receipt,
    super.key,
  });

  final String groupId;
  final PreparedGroupReceipt receipt;

  @override
  ConsumerState<ItemizedSplitPage> createState() => _ItemizedSplitPageState();
}

class _ItemizedSplitPageState extends ConsumerState<ItemizedSplitPage> {
  final Map<int, Set<String>> _assignments = <int, Set<String>>{};
  bool _submitting = false;

  TransactionDraft get _draft => widget.receipt.draft;

  List<int> get _usableItemIndices =>
      List<int>.generate(_draft.receiptItems.length, (index) => index)
          .where((index) => _draft.receiptItems[index].name.trim().isNotEmpty)
          .toList(growable: false);

  int _itemTotal(ReceiptItem item) =>
      item.totalAmountInMinor ?? item.priceMinor ?? item.unitPriceInMinor ?? 0;

  int get _itemsTotal => _usableItemIndices.fold<int>(
    0,
    (sum, index) => sum + _itemTotal(_draft.receiptItems[index]),
  );

  int get _expenseTotal => _draft.amountInMinor ?? _itemsTotal;

  bool get _totalsCompatible => _itemsTotal <= _expenseTotal;

  bool get _allAssigned =>
      _usableItemIndices.isNotEmpty &&
      _usableItemIndices.every(
        (index) => _assignments[index]?.isNotEmpty ?? false,
      );

  bool get _canSubmit =>
      widget.receipt.canUseItemizedSplit &&
      _allAssigned &&
      _itemsTotal > 0 &&
      _expenseTotal > 0 &&
      _totalsCompatible;

  Future<void> _share(GroupDetail group) async {
    if (!_canSubmit || _submitting) return;
    final currentUserId = ref.read(currentGroupUserIdProvider);
    final lineItems = <ItemizedLineItemRequest>[];

    for (final itemIndex in _usableItemIndices) {
      final assignees = _assignments[itemIndex]!.toList()..sort();
      final amounts = splitEqualInMinor(
        _itemTotal(_draft.receiptItems[itemIndex]),
        assignees.length,
      );
      lineItems.add(
        ItemizedLineItemRequest(
          receiptLineItemId: widget.receipt.cloudLineItemIds[itemIndex]!,
          shares: List<ItemizedLineItemShareRequest>.generate(
            assignees.length,
            (index) => ItemizedLineItemShareRequest(
              userId: assignees[index],
              amountInMinor: amounts[index],
              quantityShareMilli: null,
            ),
            growable: false,
          ),
        ),
      );
    }

    final extraAmount = _expenseTotal - _itemsTotal;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final request = CreateGroupExpenseRequest(
      receiptId: widget.receipt.cloudReceiptId,
      payerUserId: currentUserId,
      title: _draft.institutionName.trim().isEmpty
          ? 'Fiş masrafı'
          : _draft.institutionName.trim(),
      note: null,
      expenseDate:
          _draft.transactionDate?.toUtc().toIso8601String() ?? timestamp,
      totalAmountInMinor: _expenseTotal,
      currency: group.currency,
      split: ItemizedSplitRequest(
        lineItems: lineItems,
        extraAmountShares: extraAmount == 0
            ? const <FixedAmountSplitShareRequest>[]
            : <FixedAmountSplitShareRequest>[
                FixedAmountSplitShareRequest(
                  userId: currentUserId,
                  amountInMinor: extraAmount,
                ),
              ],
      ),
    );

    setState(() => _submitting = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .createExpense(
            groupId: group.id,
            request: request,
            idempotencyKey: 'itemized-${DateTime.now().microsecondsSinceEpoch}',
          );
      ref.invalidate(groupExpensesProvider(group.id));
      ref.invalidate(groupDebtSummaryProvider(group.id));
      if (mounted) context.go('/groups/${group.id}');
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masraf paylaşılamadı. Tekrar deneyin.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailProvider(widget.groupId));
    return Scaffold(
      key: const Key('itemized_split_page'),
      appBar: AppBar(title: const Text('Kalem Bazlı Bölüştürme')),
      body: group.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Grup üyeleri yüklenemedi.')),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(value.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _draft.institutionName.trim().isEmpty
                  ? 'Fiş masrafı'
                  : _draft.institutionName,
            ),
            if (_draft.amountInMinor != null)
              Text(
                'Toplam: ₺${formatMinorAsTurkishLira(_draft.amountInMinor!)}',
              ),
            const SizedBox(height: 16),
            for (final itemIndex in _usableItemIndices)
              _ItemAssignmentCard(
                index: itemIndex,
                item: _draft.receiptItems[itemIndex],
                members: value.members
                    .where((member) => member.leftAt == null)
                    .toList(growable: false),
                selectedIds: _assignments[itemIndex] ?? const <String>{},
                onToggle: (userId, selected) {
                  setState(() {
                    final values = _assignments.putIfAbsent(
                      itemIndex,
                      () => <String>{},
                    );
                    selected ? values.add(userId) : values.remove(userId);
                  });
                },
              ),
            if (!_allAssigned)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Atanmamış ürünler var. Her ürünü en az bir üyeye ata.',
                  key: Key('unassigned_items_warning'),
                ),
              ),
            if (!_totalsCompatible)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Ürün toplamı fiş toplamından büyük. Ürünleri düzeltmeden paylaşamazsın.',
                  key: Key('item_total_mismatch_warning'),
                ),
              ),
            if (!widget.receipt.canUseItemizedSplit)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Cloud fiş kimlikleri hazır değil. Hızlı bölüştürmeyi kullan.',
                  key: Key('receipt_not_synced_warning'),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: const Key('submit_itemized_share_button'),
          onPressed: group.asData != null && _canSubmit && !_submitting
              ? () => _share(group.requireValue)
              : null,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.group_outlined),
          label: const Text('Grupla Paylaş'),
        ),
      ),
    );
  }
}

class _ItemAssignmentCard extends StatelessWidget {
  const _ItemAssignmentCard({
    required this.index,
    required this.item,
    required this.members,
    required this.selectedIds,
    required this.onToggle,
  });

  final int index;
  final ReceiptItem item;
  final List<GroupMember> members;
  final Set<String> selectedIds;
  final void Function(String userId, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final total =
        item.totalAmountInMinor ?? item.priceMinor ?? item.unitPriceInMinor;
    return Card(
      key: Key('item_assignment_$index'),
      color: selectedIds.isEmpty
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: .35)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${item.quantity == null ? 'Miktar bilinmiyor' : 'Miktar: ${item.quantity}'} · '
              '${total == null ? 'Tutar yok' : '₺${formatMinorAsTurkishLira(total)}'}',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: members
                  .map(
                    (member) => FilterChip(
                      label: Text(member.displayName),
                      selected: selectedIds.contains(member.userId),
                      onSelected: (selected) =>
                          onToggle(member.userId, selected),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
