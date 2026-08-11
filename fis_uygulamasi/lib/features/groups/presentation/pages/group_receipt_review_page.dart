import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../transaction_draft/model/turkish_money.dart';
import '../../domain/prepared_group_receipt.dart';

bool hasUsableReceiptItems(List<ReceiptItem> receiptItems) =>
    receiptItems.any((item) => item.name.trim().isNotEmpty);

class GroupReceiptReviewPage extends StatelessWidget {
  const GroupReceiptReviewPage({
    required this.groupId,
    required this.receipt,
    super.key,
  });

  final String groupId;
  final PreparedGroupReceipt receipt;

  TransactionDraft get draft => receipt.draft;

  @override
  Widget build(BuildContext context) {
    final usableItems = draft.receiptItems
        .where((item) => item.name.trim().isNotEmpty)
        .toList(growable: false);
    return Scaffold(
      key: const Key('group_receipt_review_page'),
      appBar: AppBar(title: const Text('Fişi İncele')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            draft.institutionName.trim().isEmpty
                ? 'Grup masrafı'
                : draft.institutionName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            draft.amountInMinor == null
                ? 'Toplam tutar bulunamadı'
                : 'Fiş toplamı: ₺${formatMinorAsTurkishLira(draft.amountInMinor!)}',
            key: const Key('group_receipt_total'),
          ),
          const SizedBox(height: 20),
          Text('Ürünler', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (usableItems.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Kullanılabilir ürün kalemi bulunamadı'),
                subtitle: Text('Masraf hızlı bölüştürme ile paylaşılacak.'),
              ),
            )
          else
            ...usableItems.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.name),
                  trailing: Text(
                    item.totalAmountInMinor == null
                        ? 'Tutar yok'
                        : '₺${formatMinorAsTurkishLira(item.totalAmountInMinor!)}',
                  ),
                ),
              ),
            ),
          if (usableItems.isNotEmpty && !receipt.canUseItemizedSplit)
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('Fiş henüz buluta senkronize değil'),
                subtitle: Text(
                  'Cloud fiş kimlikleri olmadan kalem bazlı bölüştürme yapılamaz. Hızlı bölüştürme açılacak.',
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('share_with_group_button'),
            onPressed: () {
              final route = receipt.canUseItemizedSplit
                  ? '/groups/$groupId/split/itemized'
                  : '/groups/$groupId/split/fast';
              context.push(route, extra: receipt);
            },
            icon: const Icon(Icons.group_outlined),
            label: const Text('Grupla Paylaş'),
          ),
        ],
      ),
    );
  }
}
