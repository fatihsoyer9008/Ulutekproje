import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/group_repository.dart';
import '../../domain/group_models.dart';
import '../controllers/group_list_controller.dart';
import '../widgets/group_card.dart';
import '../widgets/group_empty_state.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupListControllerProvider);
    return Scaffold(
      key: const Key('groups_page'),
      appBar: AppBar(title: const Text('Gruplarım')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_group_button'),
        onPressed: () => context.push('/groups/create'),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Yeni Grup Oluştur'),
      ),
      body: state.groups.when(
        loading: () => const Center(
          key: Key('groups_loading'),
          child: CircularProgressIndicator(),
        ),
        error: (_, _) => GroupEmptyState(
          key: const Key('groups_error'),
          title: 'Gruplar yüklenemedi',
          message: 'Bağlantınızı kontrol edip yeniden deneyin.',
          icon: Icons.cloud_off_outlined,
          action: FilledButton.icon(
            key: const Key('groups_retry_button'),
            onPressed: ref.read(groupListControllerProvider.notifier).load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
          ),
        ),
        data: (groups) => groups.isEmpty
            ? GroupEmptyState(
                key: const Key('groups_empty'),
                title: 'Henüz grubun yok',
                message: 'Ortak masrafları paylaşmak için ilk grubunu oluştur.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/groups/create'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Yeni Grup Oluştur'),
                ),
              )
            : RefreshIndicator(
                onRefresh: ref.read(groupListControllerProvider.notifier).load,
                child: ListView.builder(
                  key: const Key('groups_list'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: groups.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupCardWithBalance(group: groups[index]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _GroupCardWithBalance extends ConsumerWidget {
  const _GroupCardWithBalance({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(groupDebtSummaryProvider(group.id));
    final currentUserId = ref.watch(currentGroupUserIdProvider);
    final balance = summary.asData?.value.balances
        .where((item) => item.userId == currentUserId)
        .firstOrNull;
    return GroupCard(
      group: group,
      netAmountInMinor: summary.hasError ? 0 : balance?.netAmountInMinor,
      onTap: () => context.push('/groups/${group.id}'),
    );
  }
}
