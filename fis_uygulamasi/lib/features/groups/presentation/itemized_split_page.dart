import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../transaction_draft/model/turkish_money.dart';
import '../application/itemized_split_calculator.dart';
import '../domain/group_models.dart';

class ItemizedSplitReceipt {
  const ItemizedSplitReceipt({
    required this.receiptId,
    required this.totalAmountInMinor,
    required this.lineItems,
  });

  final String? receiptId;
  final int totalAmountInMinor;
  final List<ItemizedReceiptLine> lineItems;

  bool get isCloudSynced =>
      receiptId?.trim().isNotEmpty == true &&
      lineItems.isNotEmpty &&
      lineItems.every((item) => item.isCloudSynced);
}

class ItemizedSplitFormValue {
  const ItemizedSplitFormValue({
    required this.title,
    required this.payerUserId,
    required this.receiptId,
    required this.calculation,
  });

  final String title;
  final String payerUserId;
  final String receiptId;
  final ItemizedSplitCalculation calculation;
}

typedef ItemizedSplitSubmit =
    Future<void> Function(ItemizedSplitFormValue value);

class ItemizedSplitPage extends StatefulWidget {
  const ItemizedSplitPage({
    required this.group,
    required this.currentUserId,
    required this.receipt,
    required this.onSubmit,
    this.initialTitle = '',
    super.key,
  });

  final GroupDetail group;
  final String currentUserId;
  final ItemizedSplitReceipt receipt;
  final ItemizedSplitSubmit onSubmit;
  final String initialTitle;

  @override
  State<ItemizedSplitPage> createState() => _ItemizedSplitPageState();
}

class _ItemizedSplitPageState extends State<ItemizedSplitPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final List<GroupMember> _activeMembers;
  late ItemizedSplitState _splitState;
  String? _payerUserId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _activeMembers = widget.group.members
        .where((member) => member.leftAt == null)
        .toList(growable: false);
    _payerUserId =
        _activeMembers.any((member) => member.userId == widget.currentUserId)
        ? widget.currentUserId
        : _activeMembers.firstOrNull?.userId;
    _splitState = ItemizedSplitState.initial(
      receiptTotalInMinor: widget.receipt.totalAmountInMinor,
      lineItems: widget.receipt.lineItems,
      orderedActiveMemberIds: _activeMembers
          .map((member) => member.userId)
          .toList(growable: false),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calculation = _splitState.calculation;
    return Scaffold(
      appBar: AppBar(title: const Text('Kalem Bazlı Bölüştürme')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('itemized_split_scroll_view'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Text(
                widget.group.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('itemized_split_title'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Harcama adı',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Harcama adı girin.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('itemized_split_payer'),
                initialValue: _payerUserId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kim ödedi?',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final member in _activeMembers)
                    DropdownMenuItem(
                      value: member.userId,
                      child: Text(
                        member.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _payerUserId = value),
              ),
              const SizedBox(height: 16),
              _ReceiptTotalCard(receipt: widget.receipt),
              if (widget.receipt.lineItems.isEmpty) ...[
                const SizedBox(height: 16),
                const _EmptyItemsCard(),
              ] else ...[
                if (calculation.unassignedReceiptLineItemIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _UnassignedWarning(
                    lineItems: widget.receipt.lineItems,
                    unassignedIds: calculation.unassignedReceiptLineItemIds,
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Fiş ürünleri',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (
                  var index = 0;
                  index < widget.receipt.lineItems.length;
                  index += 1
                ) ...[
                  _LineItemCard(
                    index: index,
                    lineItem: widget.receipt.lineItems[index],
                    activeMembers: _activeMembers,
                    selectedMemberIds:
                        _splitState
                            .selectedMemberIdsByLineItem[_lineSelectionKey(
                          index,
                        )] ??
                        const {},
                    onToggleMember: (userId) => setState(() {
                      _splitState = _splitState.toggleLineItemMember(
                        receiptLineItemId: _lineSelectionKey(index),
                        userId: userId,
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                if (calculation.extraAmountInMinor > 0) ...[
                  _ExtraAmountCard(
                    amountInMinor: calculation.extraAmountInMinor,
                    activeMembers: _activeMembers,
                    selectedMemberIds: _splitState.selectedExtraMemberIds,
                    onToggleMember: (userId) => setState(() {
                      _splitState = _splitState.toggleExtraMember(userId);
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                if (calculation.hasNegativeDifference)
                  _ValidationWarning(
                    key: const Key('itemized_negative_difference_warning'),
                    message:
                        'Ürün toplamı fiş toplamını '
                        '${(-calculation.extraAmountInMinor).toTLDisplay} aşıyor. '
                        'Fiş veya ürün tutarlarını düzeltin.',
                  ),
                if (calculation.hasUnknownLineTotals)
                  const _ValidationWarning(
                    key: Key('itemized_unknown_total_warning'),
                    message:
                        'Bazı ürünlerin satır toplamı belirtilmedi. '
                        'Bölüştürmeden önce ürün tutarlarını tamamlayın.',
                  ),
                const SizedBox(height: 12),
                _FinalTotalCard(calculation: calculation),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('itemized_split_submit'),
                onPressed:
                    !_submitting &&
                        widget.receipt.isCloudSynced &&
                        calculation.isBalanced &&
                        _payerUserId != null
                    ? _submit
                    : null,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Harcamayı Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lineSelectionKey(int index) =>
      widget.receipt.lineItems[index].receiptLineItemId ?? 'unsynced-$index';

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final receiptId = widget.receipt.receiptId;
    final payerId = _payerUserId;
    final calculation = _splitState.calculation;
    if (receiptId == null || payerId == null || !calculation.isBalanced) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        ItemizedSplitFormValue(
          title: _titleController.text.trim(),
          payerUserId: payerId,
          receiptId: receiptId,
          calculation: calculation,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on GroupApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'unassigned_line_items') {
        setState(() {
          _splitState = _splitState.withServerUnassignedLineItems(
            error.error.detail.unassignedReceiptLineItemIds ?? const [],
          );
        });
        _showError('Atanmayan ürünleri seçip tekrar deneyin.');
      } else if (error.code == 'receipt_not_synced') {
        _showError(
          'Fiş henüz buluta eşitlenmedi. Eşit, yüzde veya tutar bölüşümünü kullanın.',
        );
      } else {
        _showError(error.error.detail.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('Harcama kaydedilemedi. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _ReceiptTotalCard extends StatelessWidget {
  const _ReceiptTotalCard({required this.receipt});

  final ItemizedSplitReceipt receipt;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        const Icon(Icons.receipt_long_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fiş toplamı'),
              Text(
                receipt.totalAmountInMinor.toTLDisplay,
                key: const Key('itemized_receipt_total'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({
    required this.index,
    required this.lineItem,
    required this.activeMembers,
    required this.selectedMemberIds,
    required this.onToggleMember,
  });

  final int index;
  final ItemizedReceiptLine lineItem;
  final List<GroupMember> activeMembers;
  final Set<String> selectedMemberIds;
  final ValueChanged<String> onToggleMember;

  @override
  Widget build(BuildContext context) {
    final quantity = lineItem.quantityMilli == null
        ? 'Belirtilmedi'
        : _formatQuantityMilli(lineItem.quantityMilli!);
    final unitPrice = _moneyOrMissing(lineItem.unitPriceInMinor);
    final lineTotal = _moneyOrMissing(lineItem.totalAmountInMinor);
    return AppCard(
      key: Key('itemized_line_item_$index'),
      child: Semantics(
        container: true,
        label:
            '${lineItem.name}, miktar $quantity, birim fiyat $unitPrice, '
            'satır toplamı $lineTotal',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lineItem.name,
              key: Key('itemized_line_item_name_$index'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text('Miktar: $quantity'),
                Text('Birim fiyat: $unitPrice'),
                Text('Satır toplamı: $lineTotal'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Bu ürünü kimler aldı?',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in activeMembers)
                  Semantics(
                    button: true,
                    selected: selectedMemberIds.contains(member.userId),
                    label:
                        '${lineItem.name} ürününü ${member.displayName} üyesine ata',
                    child: FilterChip(
                      key: Key(
                        'itemized_line_${index}_member_${member.userId}',
                      ),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          member.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: selectedMemberIds.contains(member.userId),
                      onSelected: (_) => onToggleMember(member.userId),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtraAmountCard extends StatelessWidget {
  const _ExtraAmountCard({
    required this.amountInMinor,
    required this.activeMembers,
    required this.selectedMemberIds,
    required this.onToggleMember,
  });

  final int amountInMinor;
  final List<GroupMember> activeMembers;
  final Set<String> selectedMemberIds;
  final ValueChanged<String> onToggleMember;

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('itemized_extra_amount_card'),
    child: Semantics(
      container: true,
      label: 'KDV bahşiş servis farkı ${amountInMinor.toTLDisplay}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KDV / bahşiş / servis farkı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            amountInMinor.toTLDisplay,
            key: const Key('itemized_extra_amount'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Farkı paylaşacak kişileri seçin.'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final member in activeMembers)
                Semantics(
                  button: true,
                  selected: selectedMemberIds.contains(member.userId),
                  label: 'Ekstra tutarı ${member.displayName} üyesine ata',
                  child: FilterChip(
                    key: Key('itemized_extra_member_${member.userId}'),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        member.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: selectedMemberIds.contains(member.userId),
                    onSelected: (_) => onToggleMember(member.userId),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _UnassignedWarning extends StatelessWidget {
  const _UnassignedWarning({
    required this.lineItems,
    required this.unassignedIds,
  });

  final List<ItemizedReceiptLine> lineItems;
  final Set<String> unassignedIds;

  @override
  Widget build(BuildContext context) {
    final names = <String>[];
    for (var index = 0; index < lineItems.length; index += 1) {
      final id = lineItems[index].receiptLineItemId ?? 'unsynced-$index';
      if (unassignedIds.contains(id)) names.add(lineItems[index].name);
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Uyarı: ${unassignedIds.length} ürün atanmamış.',
      child: Card(
        key: const Key('itemized_unassigned_warning'),
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${unassignedIds.length} ürün henüz kimseye atanmadı.'
                  '${names.isEmpty ? '' : '\n${names.join(', ')}'}',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidationWarning extends StatelessWidget {
  const _ValidationWarning({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Uyarı: $message',
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            style: TextStyle(color: scheme.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

class _FinalTotalCard extends StatelessWidget {
  const _FinalTotalCard({required this.calculation});

  final ItemizedSplitCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('itemized_final_total_card'),
      color: calculation.isBalanced
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Dağıtılan: ${calculation.allocatedAmountInMinor.toTLDisplay} '
          '• Fiş: ${calculation.receiptTotalInMinor.toTLDisplay}',
          style: TextStyle(
            color: calculation.isBalanced
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyItemsCard extends StatelessWidget {
  const _EmptyItemsCard();

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('itemized_empty_state'),
    child: const Column(
      children: [
        Icon(Icons.shopping_basket_outlined, size: 44),
        SizedBox(height: 8),
        Text('Bu fişte bölüştürülecek ürün yok.'),
        SizedBox(height: 4),
        Text('Eşit, yüzde veya tutar bölüşümünü kullanabilirsiniz.'),
      ],
    ),
  );
}

String _moneyOrMissing(int? amountInMinor) =>
    amountInMinor == null ? 'Belirtilmedi' : amountInMinor.toTLDisplay;

String _formatQuantityMilli(int quantityMilli) {
  final whole = quantityMilli ~/ 1000;
  final fraction = quantityMilli.remainder(1000);
  if (fraction == 0) return whole.toString();
  return '$whole,${fraction.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
}
