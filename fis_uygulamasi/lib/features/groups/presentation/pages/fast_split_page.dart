import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/group_repository.dart';
import '../../domain/group_expense_requests.dart';
import '../../domain/group_models.dart';
import '../../domain/prepared_group_receipt.dart';
import '../../../transaction_draft/model/turkish_money.dart';
import '../widgets/split_method_selector.dart';

class FastSplitPage extends ConsumerStatefulWidget {
  const FastSplitPage({
    required this.groupId,
    required this.receipt,
    super.key,
  });

  final String groupId;
  final PreparedGroupReceipt receipt;

  @override
  ConsumerState<FastSplitPage> createState() => _FastSplitPageState();
}

class _FastSplitPageState extends ConsumerState<FastSplitPage> {
  SplitType _method = SplitType.equal;
  final Set<String> _selectedIds = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  final Map<String, TextEditingController> _amountControllers = {};
  bool _initialized = false;
  bool _submitting = false;

  int get _total => widget.receipt.draft.amountInMinor ?? 0;

  @override
  void dispose() {
    for (final controller in [
      ..._percentageControllers.values,
      ..._amountControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeMembers(List<GroupMember> members) {
    if (_initialized) return;
    _initialized = true;
    _selectedIds.addAll(members.map((member) => member.userId));
    for (final member in members) {
      _percentageControllers[member.userId] = TextEditingController();
      _amountControllers[member.userId] = TextEditingController();
    }
  }

  int get _percentageTotal => _selectedIds.fold<int>(
    0,
    (sum, id) =>
        sum + (int.tryParse(_percentageControllers[id]?.text ?? '') ?? 0),
  );

  List<int?> get _fixedAmounts => _selectedIds
      .map((id) => parseTurkishLiraToMinor(_amountControllers[id]?.text))
      .toList(growable: false);

  int get _fixedTotal =>
      _fixedAmounts.whereType<int>().fold<int>(0, (a, b) => a + b);

  bool get _valid {
    if (_total <= 0 || _selectedIds.isEmpty) return false;
    return switch (_method) {
      SplitType.equal => true,
      SplitType.percentage => _percentageTotal == 100,
      SplitType.fixedAmount =>
        _fixedAmounts.every((amount) => amount != null && amount >= 0) &&
            _fixedTotal == _total,
      SplitType.itemized => false,
    };
  }

  String? get _validationMessage {
    if (_total <= 0) return 'Paylaşılacak fiş toplamı bulunamadı.';
    if (_selectedIds.isEmpty) return 'En az bir üye seç.';
    if (_method == SplitType.percentage && _percentageTotal != 100) {
      return 'Yüzde toplamı %$_percentageTotal. Toplam tam olarak %100 olmalı.';
    }
    if (_method == SplitType.fixedAmount &&
        _fixedAmounts.any((amount) => amount == null)) {
      return 'Geçerli bir para tutarı gir.';
    }
    if (_method == SplitType.fixedAmount && _fixedTotal != _total) {
      return 'Pay toplamı ₺${formatMinorAsTurkishLira(_fixedTotal)}; fiş toplamıyla eşleşmeli.';
    }
    return null;
  }

  Future<void> _share(GroupDetail group) async {
    if (!_valid || _submitting) return;
    final selected = group.members
        .where((member) => _selectedIds.contains(member.userId))
        .toList(growable: false);
    final split = switch (_method) {
      SplitType.equal => EqualSplitRequest(
        memberIds: selected
            .map((member) => member.userId)
            .toList(growable: false),
      ),
      SplitType.percentage => PercentageSplitRequest(
        shares: selected
            .map(
              (member) => PercentageSplitShareRequest(
                userId: member.userId,
                percentageBasisPoints:
                    int.parse(_percentageControllers[member.userId]!.text) *
                    100,
              ),
            )
            .toList(growable: false),
      ),
      SplitType.fixedAmount => FixedAmountSplitRequest(
        shares: selected
            .map(
              (member) => FixedAmountSplitShareRequest(
                userId: member.userId,
                amountInMinor: parseTurkishLiraToMinor(
                  _amountControllers[member.userId]!.text,
                )!,
              ),
            )
            .toList(growable: false),
      ),
      SplitType.itemized => throw StateError('Geçersiz bölüşüm yöntemi.'),
    };
    final currentUserId = ref.read(currentGroupUserIdProvider);
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final request = CreateGroupExpenseRequest(
      receiptId: widget.receipt.cloudReceiptId,
      payerUserId: currentUserId,
      title: widget.receipt.draft.institutionName.trim().isEmpty
          ? 'Grup masrafı'
          : widget.receipt.draft.institutionName.trim(),
      note: null,
      expenseDate:
          widget.receipt.draft.transactionDate?.toUtc().toIso8601String() ??
          timestamp,
      totalAmountInMinor: _total,
      currency: group.currency,
      split: split,
    );

    setState(() => _submitting = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .createExpense(
            groupId: group.id,
            request: request,
            idempotencyKey: 'fast-${DateTime.now().microsecondsSinceEpoch}',
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
    final detail = ref.watch(groupDetailProvider(widget.groupId));
    return Scaffold(
      key: const Key('fast_split_page'),
      appBar: AppBar(title: const Text('Hızlı Bölüştürme')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Grup üyeleri yüklenemedi.')),
        data: (group) {
          final members = group.members
              .where((member) => member.leftAt == null)
              .toList();
          _initializeMembers(members);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Text(group.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Toplam: ₺${formatMinorAsTurkishLira(_total)}'),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SplitMethodSelector(
                  value: _method,
                  onChanged: (value) => setState(() => _method = value),
                ),
              ),
              const SizedBox(height: 20),
              Text('Üyeler', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...members.map((member) => _memberTile(member)),
              if (_validationMessage case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    message,
                    key: const Key('split_validation_message'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: const Key('submit_fast_share_button'),
          onPressed: detail.asData != null && _valid && !_submitting
              ? () => _share(detail.requireValue)
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

  Widget _memberTile(GroupMember member) {
    final selected = _selectedIds.contains(member.userId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => setState(() {
                value == true
                    ? _selectedIds.add(member.userId)
                    : _selectedIds.remove(member.userId);
              }),
            ),
            Expanded(child: Text(member.displayName)),
            if (selected && _method == SplitType.percentage)
              SizedBox(
                width: 92,
                child: TextField(
                  key: Key('percentage_${member.userId}'),
                  controller: _percentageControllers[member.userId],
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(suffixText: '%'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            if (selected && _method == SplitType.fixedAmount)
              SizedBox(
                width: 120,
                child: TextField(
                  key: Key('amount_${member.userId}'),
                  controller: _amountControllers[member.userId],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(prefixText: '₺'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
