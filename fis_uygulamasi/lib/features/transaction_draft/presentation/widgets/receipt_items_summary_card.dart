import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class ReceiptItemsSummaryCard extends StatelessWidget {
  const ReceiptItemsSummaryCard({
    required this.itemCount,
    required this.onViewItems,
    super.key,
  });

  final int itemCount;
  final VoidCallback onViewItems;

  @override
  Widget build(BuildContext context) {
    final description = itemCount == 0
        ? 'Fişte ürün kalemi bulunamadı.'
        : '$itemCount ürün kalemi bulundu.';

    return AppCard(
      child: Row(
        children: [
          const CircleAvatar(
            child: Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fiş ürünleri',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  key: const Key('receipt_items_summary_count'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '$itemCount fiş ürününü görüntüle',
            child: TextButton(
              key: const Key('view_receipt_items_button'),
              onPressed: onViewItems,
              child: const Text('Görüntüle'),
            ),
          ),
        ],
      ),
    );
  }
}
