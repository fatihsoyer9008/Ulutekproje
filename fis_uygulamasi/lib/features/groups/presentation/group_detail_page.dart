import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/request_id.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../application/group_expense_flow_controller.dart';
import '../data/group_api_failure.dart';
import '../data/group_providers.dart';
import '../data/fake_group_repository.dart';
import '../domain/group_expense_draft.dart';
import '../domain/group_models.dart';
import '../domain/group_offline_operation.dart';
import 'debt_summary_page.dart';
import 'fast_split_page.dart';

class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(groupExpenseFlowControllerProvider);
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
    final supportsInvitations = ref.watch(
      groupRepositoryProvider.select(
        (repository) => repository.capabilities.supportsInvitations,
      ),
    );
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
              canMutate: (expense) => _canMutateExpense(expense, currentUserId),
              onEdit: (expense) =>
                  _editExpense(context, ref, expense, currentUserId),
              onDelete: (expense) => _confirmAndDeleteExpense(
                context,
                ref,
                expense,
                currentUserId,
              ),
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
                      tooltip: supportsInvitations
                          ? 'Üye ekle'
                          : 'Davet sistemi hazırlanıyor',
                      onPressed: supportsInvitations
                          ? () => _showAddMemberSheet(context, ref)
                          : null,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    )
                  : null,
            ),
            if (_canManageMembers && !supportsInvitations) ...[
              const SizedBox(height: 4),
              const Row(
                key: Key('group_invitation_unavailable_message'),
                children: [
                  Icon(Icons.info_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Davet sistemi hazırlanıyor')),
                ],
              ),
            ],
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

  bool _canMutateExpense(GroupExpense expense, String? currentUserId) =>
      currentUserId != null &&
      (expense.createdBy == currentUserId || _canManageMembers);

  Future<void> _editExpense(
    BuildContext context,
    WidgetRef ref,
    GroupExpense expense,
    String? currentUserId,
  ) async {
    if (!_canMutateExpense(expense, currentUserId) || currentUserId == null) {
      return;
    }
    final input = await showModalBottomSheet<_ExpenseMetadataInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditExpenseSheet(expense: expense),
    );
    if (input == null || !context.mounted) return;

    try {
      final repository = ref.read(groupRepositoryProvider);
      if (repository is FakeGroupRepository) {
        await repository.updateExpenseMetadata(
          groupId: expense.groupId,
          expenseId: expense.id,
          title: input.title,
          note: input.note,
        );
      } else {
        await ref
            .read(offlineFirstGroupExpenseMutatorProvider)
            .updateMetadata(
              expense: expense,
              ownerKey: 'user:$currentUserId',
              clientRecordId: newUuidV4(),
              title: input.title,
              note: input.note,
            );
      }
      ref.invalidate(groupExpensesProvider(group.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Masraf güncellemesi kaydedildi.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_expenseMutationMessage(error))));
      }
    }
  }

  Future<void> _confirmAndDeleteExpense(
    BuildContext context,
    WidgetRef ref,
    GroupExpense expense,
    String? currentUserId,
  ) async {
    if (!_canMutateExpense(expense, currentUserId) ||
        currentUserId == null ||
        expense.isFinanciallyLocked) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('delete_group_expense_confirmation_dialog'),
        title: const Text('Masrafı sil'),
        content: Text(
          '“${expense.title}” masrafını silmek istiyor musunuz? '
          'Bu değişiklik bağlantı geldiğinde diğer cihazlara aktarılır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('confirm_delete_group_expense_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Masrafı sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final repository = ref.read(groupRepositoryProvider);
      if (repository is FakeGroupRepository) {
        await repository.deleteExpense(
          groupId: expense.groupId,
          expenseId: expense.id,
        );
      } else {
        await ref
            .read(offlineFirstGroupExpenseMutatorProvider)
            .delete(
              expense: expense,
              ownerKey: 'user:$currentUserId',
              clientRecordId: newUuidV4(),
            );
      }
      ref.invalidate(groupExpensesProvider(group.id));
      ref.invalidate(groupDebtSummaryProvider(group.id));
      ref.invalidate(groupsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Masraf silme kuyruğuna eklendi.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_expenseMutationMessage(error))));
      }
    }
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
    final idempotencyKey = newUuidV4();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FastSplitPage(
          group: group,
          currentUserId: currentUserId,
          onSubmit: (value) async {
            final controller = ref.read(
              groupExpenseFlowControllerProvider.notifier,
            );
            controller.start(
              group: group,
              activeUserId: currentUserId,
              draft: GroupExpenseDraft(
                groupId: group.id,
                payerUserId: value.payerUserId,
                merchantName: value.title,
                category: '',
                totalAmountInMinor: value.calculation.totalAmountInMinor,
                expenseDate: DateTime.now().toUtc(),
                currency: group.currency,
                rawOcrText: null,
                items: const <GroupExpenseDraftItem>[],
              ),
            );
            controller.setFastSplit(
              value.calculation,
              percentageBasisPoints: value.percentageBasisPoints,
            );
            await controller.submitFastSplit(idempotencyKey: idempotencyKey);

            final flowState = ref.read(groupExpenseFlowControllerProvider);
            if (flowState.status == GroupExpenseFlowStatus.error) {
              throw flowState.error ??
                  StateError('Grup masrafı kuyruğa eklenemedi.');
            }
            if (flowState.status != GroupExpenseFlowStatus.success) {
              throw StateError('Grup masrafı kaydı tamamlanamadı.');
            }
            controller.clear();

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
    context.push('/groups/${Uri.encodeComponent(group.id)}/ocr', extra: group);
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
            final settlementId = newUuidV4();

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

            final repository = ref.read(groupRepositoryProvider);
            if (repository is FakeGroupRepository) {
              await repository.createSettlement(
                settlement,
                idempotencyKey: settlementId,
              );
            } else {
              await ref
                  .read(offlineFirstGroupExpenseWriterProvider)
                  .saveSettlement(
                    SettlementOfflineOperation.create(
                      settlement: settlement,
                      clientRecordId: settlementId,
                      ownerKey: 'user:$currentUserId',
                    ),
                  );
            }

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

enum _ExpenseAction { edit, delete }

class _ExpenseMetadataInput {
  const _ExpenseMetadataInput({required this.title, required this.note});

  final String title;
  final String? note;
}

class _EditExpenseSheet extends StatefulWidget {
  const _EditExpenseSheet({required this.expense});

  final GroupExpense expense;

  @override
  State<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<_EditExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _noteController = TextEditingController(text: widget.expense.note);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Masrafı Düzenle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tutar, ödeyen ve paylar korunur. Bu ekrandan başlık ve notu değiştirebilirsiniz.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('edit_group_expense_title_field'),
                controller: _titleController,
                maxLength: 255,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Başlık'),
                validator: (value) {
                  final normalized = value?.trim() ?? '';
                  if (normalized.isEmpty) return 'Başlık zorunludur.';
                  if (normalized.length > 255) {
                    return 'Başlık en fazla 255 karakter olabilir.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('edit_group_expense_note_field'),
                controller: _noteController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('save_group_expense_update_button'),
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      Navigator.of(context).pop(
                        _ExpenseMetadataInput(
                          title: _titleController.text.trim(),
                          note: _noteController.text.trim().isEmpty
                              ? null
                              : _noteController.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _expenseMutationMessage(Object error) {
  if (error is StateError) return error.message.toString();
  return groupUserMessage(
    error,
    fallbackMessage: 'Masraf değişikliği kaydedilemedi. Lütfen tekrar deneyin.',
  );
}

class _ExpensesSection extends StatelessWidget {
  const _ExpensesSection({
    required this.expensesAsync,
    required this.onRetry,
    required this.canMutate,
    required this.onEdit,
    required this.onDelete,
  });

  final AsyncValue<List<GroupExpense>> expensesAsync;
  final VoidCallback onRetry;
  final bool Function(GroupExpense expense) canMutate;
  final Future<void> Function(GroupExpense expense) onEdit;
  final Future<void> Function(GroupExpense expense) onDelete;
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₺${formatMinorAsTurkishLira(expenses[index].totalAmountInMinor)}',
                      ),
                      if (canMutate(expenses[index]))
                        PopupMenuButton<_ExpenseAction>(
                          key: Key(
                            'group_expense_actions_${expenses[index].id}',
                          ),
                          tooltip: 'Masraf işlemleri',
                          onSelected: (action) {
                            switch (action) {
                              case _ExpenseAction.edit:
                                unawaited(onEdit(expenses[index]));
                                break;
                              case _ExpenseAction.delete:
                                unawaited(onDelete(expenses[index]));
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem<_ExpenseAction>(
                              key: Key(
                                'edit_group_expense_${expenses[index].id}',
                              ),
                              value: _ExpenseAction.edit,
                              child: const Text('Düzenle'),
                            ),
                            PopupMenuItem<_ExpenseAction>(
                              key: Key(
                                'delete_group_expense_${expenses[index].id}',
                              ),
                              value: _ExpenseAction.delete,
                              enabled: !expenses[index].isFinanciallyLocked,
                              child: Text(
                                expenses[index].isFinanciallyLocked
                                    ? 'Sil (finansal olarak kilitli)'
                                    : 'Sil',
                              ),
                            ),
                          ],
                        ),
                    ],
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
