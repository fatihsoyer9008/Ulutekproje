import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transaction_draft/model/turkish_money.dart';
import '../../transaction_draft/presentation/transaction_draft_page.dart';
import '../application/pending_receipts_controller.dart';
import '../domain/pending_receipt.dart';

/// n8n'in e-postadan çıkardığı, henüz onaylanmamış fişleri listeler.
/// Bir satıra dokunmak, mevcut OCR-onay akışıyla aynı taslak ekranını açar;
/// onaylanınca gider olarak kaydedilir ve sunucuda `approved` işaretlenir.
class PendingReceiptsPage extends ConsumerWidget {
  const PendingReceiptsPage({super.key, required this.saveTransaction});

  final Future<void> Function(TransactionEntity transaction)? saveTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(pendingReceiptsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Onay Bekleyenler')),
      body: receiptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bekleyen faturalar yüklenemedi.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref
                    .read(pendingReceiptsControllerProvider.notifier)
                    .refresh(),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
        data: (receipts) => _PendingReceiptsList(
          receipts: receipts,
          saveTransaction: saveTransaction,
        ),
      ),
    );
  }
}

class _PendingReceiptsList extends ConsumerWidget {
  const _PendingReceiptsList({
    required this.receipts,
    required this.saveTransaction,
  });

  final List<PendingReceipt> receipts;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (receipts.isEmpty) {
      return const Center(child: Text('Onay bekleyen fatura yok.'));
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(pendingReceiptsControllerProvider.notifier).refresh(),
      child: ListView.separated(
        itemCount: receipts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final receipt = receipts[index];
          return Dismissible(
            key: ValueKey(receipt.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Theme.of(context).colorScheme.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Icon(Icons.delete_outline),
            ),
            confirmDismiss: (_) => _confirmReject(context),
            onDismissed: (_) => ref
                .read(pendingReceiptsControllerProvider.notifier)
                .reject(receipt.id),
            child: ListTile(
              title: Text(
                (receipt.merchantName?.isNotEmpty ?? false)
                    ? receipt.merchantName!
                    : 'Bilinmeyen kurum',
              ),
              subtitle: Text(
                receipt.receiptDate == null
                    ? 'Tarih bulunamadı'
                    : _formatDate(receipt.receiptDate!),
              ),
              trailing: Text(
                receipt.totalAmountInMinor == null
                    ? '-'
                    : formatMinorAsTurkishLira(receipt.totalAmountInMinor!),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _review(context, ref, receipt),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmReject(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Faturayı reddet'),
        content: const Text(
          'Bu fatura onay listesinden kaldırılacak. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    PendingReceipt receipt,
  ) async {
    final confirmed = await Navigator.of(context).push<TransactionDraft>(
      MaterialPageRoute(
        builder: (_) => TransactionDraftPage(
          initialDraft: receipt.toTransactionDraft(),
          mode: TransactionDraftPageMode.ocrReview,
        ),
      ),
    );
    if (confirmed == null || !context.mounted) return;

    final save = saveTransaction;
    final messenger = ScaffoldMessenger.of(context);
    if (save == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kayıt servisi kullanılamıyor.')),
      );
      return;
    }

    try {
      await save(
        confirmed.toTransactionEntity(
          source: TransactionSource.ocrLlm,
          transactionType: TransactionType.expense,
        ),
      );
      await ref
          .read(pendingReceiptsControllerProvider.notifier)
          .approve(
            receipt.id,
            merchantName: confirmed.institutionName,
            totalAmountInMinor: confirmed.amountInMinor,
            receiptDate: confirmed.transactionDate,
            category: confirmed.category,
          );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Fatura onaylandı ve gider olarak kaydedildi.'),
        ),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi. Lütfen tekrar deneyin.')),
      );
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';
}
