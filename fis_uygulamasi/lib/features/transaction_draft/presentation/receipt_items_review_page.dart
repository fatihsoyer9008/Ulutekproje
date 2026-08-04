import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import '../model/receipt_total_validation.dart';
import '../model/turkish_money.dart';
import 'widgets/receipt_item_form_dialog.dart';

class ReceiptItemsReviewResult {
  const ReceiptItemsReviewResult({
    required this.items,
    this.updatedReceiptTotalInMinor,
  });

  final List<ReceiptItem> items;
  final int? updatedReceiptTotalInMinor;
}

class ReceiptItemsReviewPage extends StatefulWidget {
  const ReceiptItemsReviewPage({
    required this.initialItems,
    required this.receiptTotalInMinor,
    super.key,
  });

  final List<ReceiptItem> initialItems;
  final int? receiptTotalInMinor;

  @override
  State<ReceiptItemsReviewPage> createState() => _ReceiptItemsReviewPageState();
}

class _ReceiptItemsReviewPageState extends State<ReceiptItemsReviewPage> {
  late final List<ReceiptItem> _items = [...widget.initialItems];
  int? _updatedReceiptTotalInMinor;

  int? get _effectiveReceiptTotal =>
      _updatedReceiptTotalInMinor ?? widget.receiptTotalInMinor;

  ReceiptTotalValidation get _validation => ReceiptTotalValidation.evaluate(
    items: _items,
    mainReceiptTotalInMinor: _effectiveReceiptTotal,
  );

  void _replaceItems(VoidCallback mutation) {
    setState(() {
      mutation();
      // A previously approved receipt total only belongs to the exact item
      // list from which it was calculated. Any mutation requires fresh user
      // confirmation instead of silently keeping a stale amount.
      _updatedReceiptTotalInMinor = null;
    });
  }

  Future<void> _addItem() async {
    final item = await showDialog<ReceiptItem>(
      context: context,
      builder: (_) => const ReceiptItemFormDialog(),
    );
    if (item != null && mounted) _replaceItems(() => _items.add(item));
  }

  Future<void> _editItem(int index) async {
    final item = await showDialog<ReceiptItem>(
      context: context,
      builder: (_) => ReceiptItemFormDialog(initialItem: _items[index]),
    );
    if (item != null && mounted) {
      _replaceItems(() => _items[index] = item);
    }
  }

  Future<void> _deleteItem(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürün silinsin mi?'),
        content: Text('${_items[index].name} listeden kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('confirm_delete_receipt_item_button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && mounted) {
      _replaceItems(() => _items.removeAt(index));
    }
  }

  Future<void> _useItemsTotal() async {
    final calculated = _validation.calculatedItemsTotalInMinor;
    if (calculated == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fiş tutarı güncellensin mi?'),
        content: Text(
          'Fiş tutarı ürün toplamı olan '
          '${formatMinorAsTurkishLira(calculated)} TL yapılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('confirm_use_items_total_button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _updatedReceiptTotalInMinor = calculated);
    }
  }

  void _apply() => Navigator.of(context).pop(
    ReceiptItemsReviewResult(
      items: List.unmodifiable(_items),
      updatedReceiptTotalInMinor: _updatedReceiptTotalInMinor,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    return Scaffold(
      appBar: AppBar(title: const Text('Fiş Ürünleri')),
      body: SafeArea(
        child: Column(
          children: [
            if (validation.hasMismatch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Ürün toplamı fiş tutarıyla eşleşmiyor.',
                              key: Key('receipt_items_mismatch_warning'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ürünler: ${formatMinorAsTurkishLira(validation.calculatedItemsTotalInMinor!)} TL'
                        ' • Fiş: ${formatMinorAsTurkishLira(_effectiveReceiptTotal!)} TL',
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('use_receipt_items_total_button'),
                          onPressed: _useItemsTotal,
                          child: const Text('Fiş tutarını güncelle'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _items.isEmpty
                  ? const _EmptyReceiptItems()
                  : ListView.builder(
                      key: const Key('receipt_items_list'),
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final total =
                            ReceiptTotalValidation.calculateItemTotalInMinor(
                              item,
                            );
                        final unitPrice =
                            item.unitPriceInMinor ?? item.priceMinor;
                        final quantityLabel = item.quantity == null
                            ? 'Belirtilmedi'
                            : _formatQuantity(item.quantity!);
                        final unitPriceLabel = unitPrice == null
                            ? 'Belirtilmedi'
                            : '${formatMinorAsTurkishLira(unitPrice)} TL';
                        final totalLabel = total == null
                            ? 'Belirtilmedi'
                            : '${formatMinorAsTurkishLira(total)} TL';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            child: Semantics(
                              container: true,
                              label:
                                  '${item.name}, miktar $quantityLabel, '
                                  'birim fiyat $unitPriceLabel, '
                                  'satır toplamı $totalLabel',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          key: Key('receipt_item_$index'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      IconButton(
                                        key: Key('edit_receipt_item_$index'),
                                        tooltip: '${item.name} ürününü düzenle',
                                        onPressed: () => _editItem(index),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        key: Key('delete_receipt_item_$index'),
                                        tooltip: '${item.name} ürününü sil',
                                        onPressed: () => _deleteItem(index),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                  if (item.category?.trim().isNotEmpty == true)
                                    Text(item.category!),
                                  const SizedBox(height: 6),
                                  Text('Miktar: $quantityLabel'),
                                  Text('Birim fiyat: $unitPriceLabel'),
                                  Text('Satır toplamı: $totalLabel'),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_receipt_item_button'),
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Ürün ekle'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('cancel_receipt_items_button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('apply_receipt_items_button'),
                onPressed: _apply,
                child: const Text('Uygula'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString().replaceAll('.', ',');

class _EmptyReceiptItems extends StatelessWidget {
  const _EmptyReceiptItems();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Henüz ürün yok',
            key: const Key('receipt_items_empty_state'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Fişte görünmeyen ürünleri elle ekleyebilirsiniz.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
