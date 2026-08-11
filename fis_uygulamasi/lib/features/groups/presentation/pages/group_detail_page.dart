import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/group_repository.dart';
import '../../domain/group_models.dart';
import '../group_formatters.dart';
import '../widgets/debt_card.dart';
import '../widgets/group_empty_state.dart';
import '../widgets/member_card.dart';

class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(groupId));
    return detail.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Grup Detayı')),
        body: GroupEmptyState(
          title: 'Grup yüklenemedi',
          message: 'Grup bilgilerini yeniden yüklemeyi deneyin.',
          icon: Icons.error_outline_rounded,
          action: FilledButton(
            onPressed: () => ref.invalidate(groupDetailProvider(groupId)),
            child: const Text('Tekrar Dene'),
          ),
        ),
      ),
      data: (group) => DefaultTabController(
        length: 3,
        child: Scaffold(
          key: const Key('group_detail_page'),
          appBar: AppBar(
            title: Text(group.name),
            bottom: const TabBar(
              tabs: [
                Tab(
                  key: Key('expenses_tab'),
                  icon: Icon(Icons.receipt_long_outlined),
                  text: 'Masraflar',
                ),
                Tab(
                  key: Key('debts_tab'),
                  icon: Icon(Icons.balance_outlined),
                  text: 'Borç Özeti',
                ),
                Tab(
                  key: Key('members_tab'),
                  icon: Icon(Icons.people_outline),
                  text: 'Üyeler',
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _ExpensesTab(group: group),
              _DebtsTab(group: group),
              _MembersTab(group: group),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(groupExpensesProvider(group.id));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('scan_group_receipt_button'),
              onPressed: () => context.push('/groups/${group.id}/expenses/new'),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Masraf Ekle / Fiş Tara'),
            ),
          ),
        ),
        Expanded(
          child: expenses.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => GroupEmptyState(
              title: 'Masraflar yüklenemedi',
              message: 'Bir süre sonra tekrar deneyin.',
              action: FilledButton(
                onPressed: () =>
                    ref.invalidate(groupExpensesProvider(group.id)),
                child: const Text('Tekrar Dene'),
              ),
            ),
            data: (items) => items.isEmpty
                ? const GroupEmptyState(
                    key: Key('expenses_empty'),
                    title: 'Henüz masraf yok',
                    message: 'İlk ortak masrafı ekleyerek paylaşımı başlat.',
                    icon: Icons.receipt_long_outlined,
                  )
                : ListView.builder(
                    key: const Key('expenses_list'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final expense = items[index];
                      final payer = group.members
                          .where(
                            (member) => member.userId == expense.payerUserId,
                          )
                          .firstOrNull;
                      return Card(
                        child: ListTile(
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '${expense.title}\n${formatGroupMoney(expense.totalAmountInMinor)}',
                              ),
                            ),
                          ),
                          leading: const Icon(Icons.receipt_outlined),
                          title: Text(expense.title),
                          subtitle: Text(
                            '${payer?.displayName ?? 'Bilinmeyen üye'} ödedi · '
                            '${formatGroupDate(expense.expenseDate)} · '
                            '${_splitLabel(expense.splitType)}',
                          ),
                          trailing: Text(
                            formatGroupMoney(expense.totalAmountInMinor),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _DebtsTab extends ConsumerWidget {
  const _DebtsTab({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(groupDebtSummaryProvider(group.id));
    final currentUserId = ref.watch(currentGroupUserIdProvider);
    final names = {
      for (final member in group.members) member.userId: member.displayName,
    };
    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => GroupEmptyState(
        title: 'Borç özeti yüklenemedi',
        message: 'Bir süre sonra tekrar deneyin.',
        action: FilledButton(
          onPressed: () => ref.invalidate(groupDebtSummaryProvider(group.id)),
          child: const Text('Tekrar Dene'),
        ),
      ),
      data: (value) {
        final currentBalance =
            value.balances
                .where((balance) => balance.userId == currentUserId)
                .firstOrNull
                ?.netAmountInMinor ??
            0;
        if (value.suggestedTransfers.isEmpty && currentBalance == 0) {
          return const GroupEmptyState(
            key: Key('debts_empty'),
            title: 'Hesaplar dengede',
            message: 'Bu grupta ödenmesi gereken borç bulunmuyor.',
            icon: Icons.handshake_outlined,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Net durumun',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatNetPosition(currentBalance),
                      key: const Key('net_debt_position'),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Önerilen ödemeler',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...value.suggestedTransfers.map(
              (transfer) => DebtCard(
                transfer: transfer,
                memberNames: names,
                currentUserId: currentUserId,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const Key('members_list'),
    padding: const EdgeInsets.all(16),
    itemCount: group.members.length,
    itemBuilder: (_, index) => MemberCard(member: group.members[index]),
  );
}

String _splitLabel(SplitType type) => switch (type) {
  SplitType.equal => 'Eşit bölüşüm',
  SplitType.percentage => 'Yüzdelik bölüşüm',
  SplitType.fixedAmount => 'Tutar bazlı bölüşüm',
  SplitType.itemized => 'Kalem bazlı bölüşüm',
};
