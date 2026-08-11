import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../data/fake_group_repository.dart';
import '../domain/group_models.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final currentUserId = ref.watch(authSessionControllerProvider).user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Gruplarım')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_group_button'),
        onPressed: () => _showCreateGroupSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Grup Oluştur'),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _GroupsErrorState(onRetry: () => ref.invalidate(groupsProvider)),
        data: (response) {
          if (response.groups.isEmpty) {
            return const _GroupsEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: response.groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _GroupCard(
              group: response.groups[index],
              currentUserId: currentUserId,
            ),
          );
        },
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, required this.currentUserId});

  final Group group;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(groupDebtSummaryProvider(group.id));

    return AppCard(
      child: ListTile(
        key: Key('group_card_${group.id}'),
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.mint,
          foregroundColor: AppColors.primary,
          child: const Icon(Icons.groups_outlined),
        ),
        title: Text(group.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${group.memberCount} üye'),
        ),
        trailing: SizedBox(
          width: 110,
          child: Text(
            _netStatusText(debtAsync, currentUserId),
            key: Key('group_net_status_${group.id}'),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  String _netStatusText(
    AsyncValue<DebtSummary> debtAsync,
    String? currentUserId,
  ) {
    if (currentUserId == null) {
      return 'Net durum yok';
    }

    return debtAsync.when(
      loading: () => 'Hesaplanıyor…',
      error: (_, _) => 'Alınamadı',
      data: (summary) {
        var netAmountInMinor = 0;

        for (final balance in summary.balances) {
          if (balance.userId == currentUserId) {
            netAmountInMinor = balance.netAmountInMinor;
            break;
          }
        }

        final amount = '₺${formatMinorAsTurkishLira(netAmountInMinor.abs())}';

        if (netAmountInMinor > 0) {
          return '+$amount alacak';
        }

        if (netAmountInMinor < 0) {
          return '-$amount borç';
        }

        return 'Dengede';
      },
    );
  }
}

class _GroupsEmptyState extends StatelessWidget {
  const _GroupsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.mint,
                  foregroundColor: AppColors.primary,
                  child: const Icon(Icons.groups_outlined, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz grubunuz yok',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ortak harcamalarınızı yönetmek için yeni bir grup oluşturun.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupsErrorState extends StatelessWidget {
  const _GroupsErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 36),
              const SizedBox(height: 12),
              Text(
                'Gruplar yüklenemedi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Lütfen bağlantınızı kontrol edip tekrar deneyin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCreateGroupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CreateGroupSheet(),
  );
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Yeni Grup Oluştur',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Ortak harcamalarınızı bu grup altında yönetin.'),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('group_name_field'),
                controller: _nameController,
                autofocus: true,
                maxLength: 120,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Grup adı',
                  hintText: 'Örn. Ev arkadaşları',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';

                  if (name.isEmpty) {
                    return 'Grup adı boş bırakılamaz.';
                  }

                  if (name.length > 120) {
                    return 'Grup adı en fazla 120 karakter olabilir.';
                  }

                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('create_group_submit_button'),
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Grubu Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(groupRepositoryProvider)
          .createGroup(name: _nameController.text.trim());

      ref.invalidate(groupsProvider);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Grup oluşturuldu.')),
      );
    } on GroupApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.error.detail.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Grup oluşturulamadı. Lütfen tekrar deneyin.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
