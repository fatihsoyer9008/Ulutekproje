import 'package:flutter/material.dart';

import '../../transaction_draft/model/turkish_money.dart';
import '../domain/group_models.dart';

typedef DebtSummaryLoader = Future<DebtSummary> Function();
typedef MarkDebtTransferPaid = Future<void> Function(DebtTransfer transfer);

class DebtSummaryPage extends StatefulWidget {
  const DebtSummaryPage({
    required this.groupName,
    required this.currentUserId,
    required this.loadSummary,
    required this.onMarkPaid,
    super.key,
  });

  final String groupName;
  final String currentUserId;
  final DebtSummaryLoader loadSummary;
  final MarkDebtTransferPaid onMarkPaid;

  @override
  State<DebtSummaryPage> createState() => _DebtSummaryPageState();
}

class _DebtSummaryPageState extends State<DebtSummaryPage> {
  DebtSummary? _summary;
  Object? _error;
  bool _loading = true;
  final Set<String> _settlingTransfers = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.loadSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Borç Özeti')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        key: Key('debt_summary_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return _MessageState(
        key: const Key('debt_summary_error'),
        icon: Icons.cloud_off_outlined,
        title: 'Borç özeti yüklenemedi',
        message: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
        actionLabel: 'Tekrar Dene',
        onAction: _load,
      );
    }
    final summary = _summary!;
    if (summary.balances.isEmpty && summary.suggestedTransfers.isEmpty) {
      return _MessageState(
        key: const Key('debt_summary_empty'),
        icon: Icons.handshake_outlined,
        title: 'Henüz borç hareketi yok',
        message: '${widget.groupName} grubundaki harcamalar burada görünecek.',
      );
    }

    final currentBalance = summary.balances
        .where((balance) => balance.userId == widget.currentUserId)
        .fold<int>(0, (total, balance) => total + balance.netAmountInMinor);
    final yourDebt = currentBalance < 0 ? -currentBalance : 0;
    final owedToYou = currentBalance > 0 ? currentBalance : 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.groupName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  key: const Key('your_debt_card'),
                  title: 'Senin borcun',
                  amountInMinor: yourDebt,
                  color: Theme.of(context).colorScheme.errorContainer,
                  icon: Icons.arrow_outward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  key: const Key('owed_to_you_card'),
                  title: 'Sana borçlu olanlar',
                  amountInMinor: owedToYou,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  icon: Icons.south_west_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Önerilen ödemeler',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (summary.suggestedTransfers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tüm borçlar kapatılmış görünüyor.'),
              ),
            )
          else
            for (final transfer in summary.suggestedTransfers)
              _transferTile(summary, transfer),
        ],
      ),
    );
  }

  Widget _transferTile(DebtSummary summary, DebtTransfer transfer) {
    final transferKey = '${transfer.fromUserId}-${transfer.toUserId}';
    final isSettling = _settlingTransfers.contains(transferKey);
    final canMarkPaid = transfer.fromUserId == widget.currentUserId;
    return Card(
      key: Key('debt_transfer_$transferKey'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_displayName(summary, transfer.fromUserId)} → '
              '${_displayName(summary, transfer.toUserId)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              transfer.amountInMinor.toTLDisplay,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (canMarkPaid) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  key: Key('mark_paid_$transferKey'),
                  onPressed: isSettling
                      ? null
                      : () => _confirmAndSettle(transfer),
                  icon: isSettling
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Ödeme yapıldı'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayName(DebtSummary summary, String userId) {
    for (final balance in summary.balances) {
      if (balance.userId == userId) return balance.displayName;
    }
    return 'Grup üyesi';
  }

  Future<void> _confirmAndSettle(DebtTransfer transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('settlement_confirmation_dialog'),
        title: const Text('Ödemeyi onayla'),
        content: Text(
          '${transfer.amountInMinor.toTLDisplay} tutarındaki ödemeyi '
          'yapıldı olarak işaretlemek istiyor musun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('confirm_settlement'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final transferKey = '${transfer.fromUserId}-${transfer.toUserId}';
    setState(() => _settlingTransfers.add(transferKey));
    try {
      await widget.onMarkPaid(transfer);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ödeme kaydedilemedi. Tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _settlingTransfers.remove(transferKey));
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amountInMinor,
    required this.color,
    required this.icon,
    super.key,
  });

  final String title;
  final int amountInMinor;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 16),
            Text(title, maxLines: 2),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                amountInMinor.toTLDisplay,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
