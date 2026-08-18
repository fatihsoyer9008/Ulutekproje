import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/group_expense_conflict_service.dart';
import '../data/group_providers.dart';
import '../domain/group_offline_operation.dart';

class GroupExpenseConflictsPage extends ConsumerStatefulWidget {
  const GroupExpenseConflictsPage({super.key});

  @override
  ConsumerState<GroupExpenseConflictsPage> createState() =>
      _GroupExpenseConflictsPageState();
}

class _GroupExpenseConflictsPageState
    extends ConsumerState<GroupExpenseConflictsPage> {
  int? _resolvingTaskId;

  @override
  Widget build(BuildContext context) {
    final conflicts = ref.watch(groupExpenseConflictsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Masraf çakışmalarını çöz')),
      body: conflicts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorState(
          onRetry: () => ref.invalidate(groupExpenseConflictsProvider),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) return const _ExplanationCard();
                  final conflict = items[index - 1];
                  return _ConflictCard(
                    conflict: conflict,
                    resolving: _resolvingTaskId == conflict.taskId,
                    onUseServer: () => _resolve(
                      conflict,
                      resolution: _ConflictResolution.server,
                    ),
                    onKeepLocal: conflict.canKeepLocal
                        ? () => _resolve(
                            conflict,
                            resolution: _ConflictResolution.local,
                          )
                        : null,
                  );
                },
              ),
      ),
    );
  }

  Future<void> _resolve(
    GroupExpenseConflict conflict, {
    required _ConflictResolution resolution,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key('resolve_conflict_dialog_${conflict.taskId}'),
        title: Text(
          resolution == _ConflictResolution.server
              ? 'Sunucu sürümü kullanılsın mı?'
              : 'Yerel değişiklik korunsun mu?',
        ),
        content: Text(
          resolution == _ConflictResolution.server
              ? 'Bu cihazdaki bekleyen değişiklik kaldırılacak ve sunucudaki güncel masraf gösterilecek.'
              : 'Sunucudaki güncel sürüm baz alınarak yerel değişiklik yeni bir işlem olarak tekrar gönderilecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: Key('confirm_conflict_resolution_${conflict.taskId}'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final userId = ref.read(currentGroupUserIdProvider);
    if (userId == null) {
      _showMessage('Çakışmayı çözmek için tekrar giriş yapın.');
      return;
    }
    setState(() => _resolvingTaskId = conflict.taskId);
    try {
      final service = ref.read(groupExpenseConflictServiceProvider);
      if (resolution == _ConflictResolution.server) {
        await service.useServerVersion(conflict, ownerKey: 'user:$userId');
      } else {
        await service.keepLocalVersion(conflict, ownerKey: 'user:$userId');
      }
      ref.invalidate(groupExpensesProvider(conflict.operation.groupId));
      ref.invalidate(groupDebtSummaryProvider(conflict.operation.groupId));
      ref.invalidate(groupsProvider);
      _showMessage('Masraf çakışması çözüldü.');
    } on Object catch (error) {
      _showMessage(_resolutionError(error));
    } finally {
      if (mounted) setState(() => _resolvingTaskId = null);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard();

  @override
  Widget build(BuildContext context) => const AppCard(
    child: Text(
      'Aynı masraf başka bir cihazda değiştirildiğinde hangi sürümün korunacağını seçin. Finansal olarak kilitli veya sunucuda silinmiş kayıtlarda yalnız sunucu sürümü kullanılabilir.',
    ),
  );
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.resolving,
    required this.onUseServer,
    required this.onKeepLocal,
  });

  final GroupExpenseConflict conflict;
  final bool resolving;
  final VoidCallback onUseServer;
  final VoidCallback? onKeepLocal;

  @override
  Widget build(BuildContext context) {
    final expense = conflict.localExpense;
    return AppCard(
      child: Column(
        key: Key('group_expense_conflict_${conflict.taskId}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_problem_rounded, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  expense?.title ?? 'Silinen grup masrafı',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(_operationLabel(conflict.operation.type))),
            ],
          ),
          const SizedBox(height: 10),
          Text(conflict.message),
          const SizedBox(height: 6),
          Text(
            'Grup: ${conflict.operation.groupId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (expense != null) ...[
            const SizedBox(height: 4),
            Text(
              'Yerel sürüm: ${expense.totalAmountInMinor / 100} ${expense.currency}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          if (resolving)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  key: Key('use_server_conflict_${conflict.taskId}'),
                  onPressed: onUseServer,
                  child: const Text('Sunucu sürümünü kullan'),
                ),
                FilledButton(
                  key: Key('keep_local_conflict_${conflict.taskId}'),
                  onPressed: onKeepLocal,
                  child: const Text('Yerel değişikliği koru'),
                ),
              ],
            ),
          if (!conflict.canKeepLocal) ...[
            const SizedBox(height: 8),
            Text(
              'Bu kayıt finansal olarak kilitli veya sunucuda silinmiş; yerel sürüm tekrar gönderilemez.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Çözüm bekleyen grup masrafı yok.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Çakışmaları yeniden yükle'),
    ),
  );
}

enum _ConflictResolution { server, local }

String _operationLabel(GroupOfflineOperationType type) => switch (type) {
  GroupOfflineOperationType.groupExpenseCreate => 'Oluşturma',
  GroupOfflineOperationType.groupExpenseUpdate => 'Güncelleme',
  GroupOfflineOperationType.groupExpenseDelete => 'Silme',
  _ => 'Grup işlemi',
};

String _resolutionError(Object error) => error
    .toString()
    .replaceFirst('Bad state: ', '')
    .replaceFirst('Exception: ', '');
