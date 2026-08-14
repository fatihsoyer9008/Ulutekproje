import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../data/group_api_failure.dart';
import '../data/group_providers.dart';
import '../domain/group_models.dart';
import 'debt_summary_page.dart';
import 'fast_split_page.dart';

class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Grup Detayı')),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailErrorState(
          message: groupUserMessage(
            error,
            fallbackMessage: 'Grup detayı yüklenemedi. Lütfen tekrar deneyin.',
          ),
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
        data: (group) => _GroupDetailContent(group: group),
      ),
    );
  }
}

class _GroupDetailContent extends ConsumerWidget {
  const _GroupDetailContent({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(group.id));
    final currentUserId = ref.watch(authSessionControllerProvider).user?.id;
    final description = group.description?.trim();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    key: const Key('group_detail_name'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${group.memberCount} üye',
                    key: const Key('group_detail_member_count'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(description ?? ''),
                  ],
                  const SizedBox(height: 12),
                  _RoleChip(role: group.currentUserRole),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionTitle(
              title: 'Masraflar',
              action: SizedBox(
                width: 180,
                child: FilledButton.icon(
                  key: const Key('add_group_expense_button'),
                  onPressed: currentUserId == null
                      ? null
                      : () => _showExpenseTypeSelector(
                          context,
                          ref,
                          currentUserId,
                        ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Yeni Masraf Ekle'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ExpensesSection(
              expensesAsync: expensesAsync,
              onRetry: () => ref.invalidate(groupExpensesProvider(group.id)),
            ),
            const SizedBox(height: 20),

            _SectionTitle(title: 'Borç Özeti'),
            const SizedBox(height: 8),
            AppCard(
              child: ListTile(
                key: const Key('open_debt_summary_button'),
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Borç Özetini Görüntüle'),
                subtitle: const Text('Grup bakiyeleri ve ödeme önerileri'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: currentUserId == null
                    ? null
                    : () => _openDebtSummary(context, ref, currentUserId),
              ),
            ),
            const SizedBox(height: 20),

            _SectionTitle(
              title: 'Üyeler',
              action: _canManageMembers
                  ? IconButton(
                      key: const Key('add_group_member_button'),
                      tooltip: 'Üye ekle',
                      onPressed: () => _showAddMemberSheet(context, ref),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            _MembersSection(
              members: group.members,
              currentUserId: currentUserId,
              currentUserRole: group.currentUserRole,
              onRemoveMember: _canManageMembers
                  ? (member) => _confirmAndRemoveMember(context, ref, member)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExpenseTypeSelector(
    BuildContext context,
    WidgetRef ref,
    String currentUserId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bölüştürme Türünü Seç',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                key: const Key('select_scan_receipt_button'),
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Fiş Tara'),
                subtitle: const Text(
                  'Kamera veya galeriden fiş bilgilerini otomatik oku.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openGroupOcr(context);
                },
              ),
              ListTile(
                key: const Key('select_fast_split_button'),
                leading: const Icon(Icons.flash_on_outlined),
                title: const Text('Hızlı Bölüştürme'),
                subtitle: const Text(
                  'Tutarı eşit, yüzde veya sabit tutar ile paylaş.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openFastSplit(context, ref, currentUserId);
                },
              ),
              ListTile(
                key: const Key('select_itemized_split_button'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Kalem Bazlı Bölüştürme'),
                subtitle: const Text('Fişteki ürün kalemlerini üyelere dağıt.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Kalem bazlı bölüştürme için önce ürün kalemleri buluta eşitlenmiş bir fiş seçilmelidir.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFastSplit(
    BuildContext context,
    WidgetRef ref,
    String currentUserId,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FastSplitPage(
          group: group,
          currentUserId: currentUserId,
          onSubmit: (value) async {
            final nowText = DateTime.now().toUtc().toIso8601String();

            final split = switch (value.calculation.type) {
              SplitType.equal => ExpenseSplitRequest.equal(
                memberIds: value.calculation.shares
                    .map((share) => share.userId)
                    .toList(growable: false),
              ),
              SplitType.percentage => ExpenseSplitRequest.percentage(
                shares: [
                  for (final share in value.calculation.shares)
                    ExpenseSplitShareRequest.percentage(
                      userId: share.userId,
                      percentageBasisPoints:
                          value.percentageBasisPoints[share.userId]!,
                    ),
                ],
              ),
              SplitType.fixedAmount => ExpenseSplitRequest.fixedAmount(
                shares: [
                  for (final share in value.calculation.shares)
                    ExpenseSplitShareRequest.fixedAmount(
                      userId: share.userId,
                      amountInMinor: share.amountInMinor,
                    ),
                ],
              ),
              SplitType.itemized => throw StateError(
                'Fast Split itemized bölüştürmeyi desteklemez.',
              ),
            };

            final request = CreateGroupExpenseRequest(
              groupId: group.id,
              receiptId: null,
              payerUserId: value.payerUserId,
              title: value.title,
              note: null,
              expenseDate: nowText,
              totalAmountInMinor: value.calculation.totalAmountInMinor,
              currency: group.currency,
              split: split,
            );

            await ref
                .read(groupExpenseRepositoryProvider)
                .createExpense(
                  request,
                  idempotencyKey:
                      'fast-split-${DateTime.now().microsecondsSinceEpoch}',
                );

            ref.invalidate(groupExpensesProvider(group.id));
            ref.invalidate(groupDebtSummaryProvider(group.id));
            ref.invalidate(groupsProvider);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Masraf kaydedildi.')),
              );
            }
          },
        ),
      ),
    );
  }

  void _openGroupOcr(BuildContext context) {
    context.push('/groups/${Uri.encodeComponent(group.id)}/ocr');
  }

  Future<void> _openDebtSummary(
    BuildContext context,
    WidgetRef ref,
    String currentUserId,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DebtSummaryPage(
          groupName: group.name,
          currentUserId: currentUserId,
          loadSummary: () =>
              ref.read(debtSummaryRepositoryProvider).getDebtSummary(group.id),
          onMarkPaid: (transfer) async {
            final now = DateTime.now().toUtc();
            final nowText = now.toIso8601String();
            final settlementId = 'settlement-${now.microsecondsSinceEpoch}';

            final settlement = Settlement(
              id: settlementId,
              groupId: group.id,
              fromUserId: transfer.fromUserId,
              toUserId: transfer.toUserId,
              amountInMinor: transfer.amountInMinor,
              currency: group.currency,
              settledAt: nowText,
              note: null,
              createdAt: nowText,
            );

            await ref
                .read(groupRepositoryProvider)
                .createSettlement(
                  settlement,
                  idempotencyKey: 'settlement-$settlementId',
                );

            ref.invalidate(groupDebtSummaryProvider(group.id));
            ref.invalidate(groupSettlementsProvider(group.id));
            ref.invalidate(groupsProvider);
          },
        ),
      ),
    );

    ref.invalidate(groupDebtSummaryProvider(group.id));
    ref.invalidate(groupsProvider);
  }

  bool get _canManageMembers =>
      group.currentUserRole == GroupRole.owner ||
      group.currentUserRole == GroupRole.admin;

  Future<void> _showAddMemberSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMemberSheet(
        canChooseAdmin: group.currentUserRole == GroupRole.owner,
        onSubmit: (email, role) async {
          await ref
              .read(groupRepositoryProvider)
              .createInvitation(groupId: group.id, email: email, role: role);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Grup daveti gönderildi.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmAndRemoveMember(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('remove_member_confirmation_dialog'),
        title: const Text('Üyeyi çıkar'),
        content: Text(
          '${member.displayName} adlı üyeyi gruptan çıkarmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('confirm_remove_member_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Üyeyi çıkar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(groupRepositoryProvider)
          .removeMember(groupId: group.id, userId: member.userId);
      ref.invalidate(groupDetailProvider(group.id));
      ref.invalidate(groupsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Üye gruptan çıkarıldı.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              groupUserMessage(
                error,
                fallbackMessage:
                    'Üye gruptan çıkarılamadı. Lütfen tekrar deneyin.',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    );
  }
}

class _ExpensesSection extends StatelessWidget {
  const _ExpensesSection({required this.expensesAsync, required this.onRetry});

  final AsyncValue<List<GroupExpense>> expensesAsync;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return expensesAsync.when(
      loading: () => const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, _) => AppCard(
        child: ListTile(
          leading: const Icon(Icons.error_outline_rounded),
          title: const Text('Masraflar yüklenemedi'),
          subtitle: Text(
            groupUserMessage(
              error,
              fallbackMessage: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
            ),
            key: const Key('group_expenses_error_message'),
          ),
          trailing: TextButton(
            key: const Key('retry_group_expenses_button'),
            onPressed: onRetry,
            child: const Text('Tekrar dene'),
          ),
        ),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const AppCard(
            child: ListTile(
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('Henüz masraf yok'),
              subtitle: Text('İlk ortak masrafı ekleyebilirsiniz.'),
            ),
          );
        }

        return AppCard(
          child: Column(
            children: [
              for (var index = 0; index < expenses.length; index++) ...[
                ListTile(
                  key: Key('group_expense_${expenses[index].id}'),
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(expenses[index].title),
                  subtitle: Text(expenses[index].expenseDate),
                  trailing: Text(
                    '₺${formatMinorAsTurkishLira(expenses[index].totalAmountInMinor)}',
                  ),
                ),
                if (index < expenses.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.members,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onRemoveMember,
  });

  final List<GroupMember> members;
  final String? currentUserId;
  final GroupRole currentUserRole;
  final ValueChanged<GroupMember>? onRemoveMember;

  @override
  Widget build(BuildContext context) {
    final activeMembers = members
        .where((member) => member.leftAt == null)
        .toList(growable: false);

    if (activeMembers.isEmpty) {
      return const AppCard(
        child: ListTile(
          leading: Icon(Icons.people_outline_rounded),
          title: Text('Aktif üye bulunmuyor'),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var index = 0; index < activeMembers.length; index++) ...[
            _MemberTile(
              member: activeMembers[index],
              currentUserId: currentUserId,
              currentUserRole: currentUserRole,
              onRemoveMember: onRemoveMember,
            ),
            if (index < activeMembers.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onRemoveMember,
  });

  final GroupMember member;
  final String? currentUserId;
  final GroupRole currentUserRole;
  final ValueChanged<GroupMember>? onRemoveMember;

  @override
  Widget build(BuildContext context) {
    final canRemove =
        onRemoveMember != null &&
        member.userId != currentUserId &&
        member.role != GroupRole.owner &&
        (currentUserRole == GroupRole.owner ||
            (currentUserRole == GroupRole.admin &&
                member.role == GroupRole.member));

    return ListTile(
      key: Key('group_member_${member.userId}'),
      leading: CircleAvatar(child: Text(_initial(member.displayName))),
      title: Text(member.displayName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoleChip(role: member.role),
          if (canRemove)
            IconButton(
              key: Key('remove_group_member_${member.userId}'),
              tooltip: 'Üyeyi çıkar',
              onPressed: () => onRemoveMember!(member),
              icon: const Icon(Icons.person_remove_alt_1_outlined),
            ),
        ],
      ),
    );
  }

  String _initial(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return '?';
    return trimmedName.substring(0, 1).toUpperCase();
  }
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.canChooseAdmin, required this.onSubmit});

  final bool canChooseAdmin;
  final Future<void> Function(String email, GroupRole role) onSubmit;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  GroupRole _role = GroupRole.member;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
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
                'Gruba Davet Et',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Davet bağlantısı bu e-posta adresine gönderilecektir.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('group_invitation_email_field'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'E-posta adresi',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Geçerli bir e-posta adresi girin.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              if (widget.canChooseAdmin) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<GroupRole>(
                  key: const Key('group_invitation_role_field'),
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: GroupRole.member,
                      child: Text('Üye'),
                    ),
                    DropdownMenuItem(
                      value: GroupRole.admin,
                      child: Text('Admin'),
                    ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) =>
                            setState(() => _role = value ?? GroupRole.member),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('submit_group_invitation_button'),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Daveti Gönder'),
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
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(_emailController.text.trim(), _role);

      if (mounted) Navigator.of(context).pop();
    } on GroupApiException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = groupUserMessage(
            error,
            fallbackMessage: 'Davet gönderilemedi. Lütfen tekrar deneyin.',
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = groupUserMessage(
            error,
            fallbackMessage: 'Davet gönderilemedi. Lütfen tekrar deneyin.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final GroupRole role;

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      GroupRole.owner => 'Owner',
      GroupRole.admin => 'Admin',
      GroupRole.member => 'Üye',
    };

    return Chip(key: Key('group_role_${role.name}'), label: Text(label));
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

  final String message;
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
                'Grup detayı yüklenemedi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                key: const Key('group_detail_error_message'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('group_detail_retry_button'),
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
