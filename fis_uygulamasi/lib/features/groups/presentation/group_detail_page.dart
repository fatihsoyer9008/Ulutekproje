import 'dart:async';
import 'dart:io';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/request_id.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../../avatar/presentation/widgets/avatar_badge.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../application/group_expense_flow_controller.dart';
import '../data/group_api_failure.dart';
import '../data/group_providers.dart';
import '../data/fake_group_repository.dart';
import '../domain/friend_models.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: groupAsync.when(
        loading: () => const _GroupDetailLoadingState(),
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

class _GroupDetailContent extends ConsumerStatefulWidget {
  const _GroupDetailContent({required this.group});

  final GroupDetail group;

  @override
  ConsumerState<_GroupDetailContent> createState() =>
      _GroupDetailContentState();
}

class _GroupDetailContentState extends ConsumerState<_GroupDetailContent> {
  late final ScrollController _scrollController;
  String? _coverImagePath;
  DateTime? _settleUpDate;

  GroupDetail get group => widget.group;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(keepScrollOffset: false);
    unawaited(_loadCoverImage());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(groupExpensesProvider(group.id));
    final debtAsync = ref.watch(groupDebtSummaryProvider(group.id));
    final currentUserId = ref.watch(authSessionControllerProvider).user?.id;
    final supportsInvitations = ref.watch(
      groupRepositoryProvider.select(
        (repository) => repository.capabilities.supportsInvitations,
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: CustomScrollView(
            key: const Key('group_detail_scroll_view'),
            controller: _scrollController,
            primary: false,
            slivers: [
              SliverToBoxAdapter(
                child: _GroupHeaderSection(
                  group: group,
                  coverImagePath: _coverImagePath,
                  settleUpDate: _settleUpDate,
                  onSelectSettleUpDate: _selectSettleUpDate,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/groups');
                    }
                  },
                  onSettings: () => _showGroupSettingsSheet(
                    context,
                    supportsInvitations: supportsInvitations,
                  ),
                ),
              ),
              SliverPadding(
                key: const Key('group_detail_content_padding'),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _BalanceSummary(
                      debtAsync: debtAsync,
                      group: group,
                      currentUserId: currentUserId,
                    ),
                    const SizedBox(height: 28),
                    _ActionButtons(
                      onSettleUp: currentUserId == null
                          ? null
                          : () => _openDebtSummary(context, ref, currentUserId),
                      onCharts: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Grup grafikleri yakında.'),
                            ),
                          ),
                      onBalances: currentUserId == null
                          ? null
                          : () => _openDebtSummary(context, ref, currentUserId),
                    ),
                    const SizedBox(height: 28),
                    _GroupExpensesList(
                      expensesAsync: expensesAsync,
                      currentUserId: currentUserId,
                      members: group.members,
                      onRetry: () =>
                          ref.invalidate(groupExpensesProvider(group.id)),
                      canMutate: (expense) =>
                          _canMutateExpense(expense, currentUserId),
                      onEdit: (expense) =>
                          _editExpense(context, ref, expense, currentUserId),
                      onDelete: (expense) => _confirmAndDeleteExpense(
                        context,
                        ref,
                        expense,
                        currentUserId,
                      ),
                    ),
                    const SizedBox(height: 32),
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
                          ? (member) =>
                                _confirmAndRemoveMember(context, ref, member)
                          : null,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
          child: FilledButton.icon(
            key: const Key('add_group_expense_button'),
            onPressed: currentUserId == null
                ? null
                : () => _showExpenseTypeSelector(context, ref, currentUserId),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A86B),
              foregroundColor: Colors.white,
              minimumSize: const Size(172, 58),
              shape: const StadiumBorder(),
              elevation: 8,
            ),
            icon: const Icon(Icons.receipt_outlined),
            label: const Text(
              'Harcama ekle',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  bool _canMutateExpense(GroupExpense expense, String? currentUserId) =>
      currentUserId != null &&
      (expense.createdBy == currentUserId || _canManageMembers);

  Future<void> _selectSettleUpDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _settleUpDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Ödeme tarihini seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (!mounted || selectedDate == null) return;
    setState(() => _settleUpDate = selectedDate);
  }

  String get _coverPreferenceKey => 'group_cover_image_${group.id}';

  Future<void> _loadCoverImage() async {
    final preferences = await SharedPreferences.getInstance();
    final path = preferences.getString(_coverPreferenceKey);
    if (!mounted || path == null) return;
    if (await File(path).exists()) setState(() => _coverImagePath = path);
  }

  Future<void> _showGroupSettingsSheet(
    BuildContext context, {
    required bool supportsInvitations,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final notificationsEnabled =
        preferences.getBool('group_notifications_${group.id}') ?? true;
    if (!mounted || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _GroupSettingsBottomSheet(
        groupName: group.name,
        currency: group.currency,
        isOwner: group.currentUserRole == GroupRole.owner,
        notificationsEnabled: notificationsEnabled,
        onEditGroup: () => _showTemporarySettingsMessage(
          context,
          'Grup bilgilerini düzenleme yakında eklenecek.',
        ),
        onGroupPhoto: () => _showCoverSourceSheet(context),
        onInviteMember: () {
          if (_canManageMembers && supportsInvitations) {
            _showAddMemberSheet(context, ref);
          } else {
            _showTemporarySettingsMessage(
              context,
              'Bu grupta üye davet etme yetkiniz bulunmuyor.',
            );
          }
        },
        onNotificationsChanged: (value) =>
            preferences.setBool('group_notifications_${group.id}', value),
        onCurrency: () => _showTemporarySettingsMessage(
          context,
          'Varsayılan para birimi değiştirme yakında eklenecek.',
        ),
        onLeaveGroup: () => _confirmGroupAction(context, deleteGroup: false),
        onDeleteGroup: () => _confirmGroupAction(context, deleteGroup: true),
      ),
    );
  }

  Future<void> _showCoverSourceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Grup fotoğrafı'),
              subtitle: Text('Kapak alanında gösterilecek görseli seçin.'),
            ),
            ListTile(
              key: const Key('pick_group_cover_gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_pickCoverImage(ImageSource.gallery));
              },
            ),
            ListTile(
              key: const Key('pick_group_cover_camera'),
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamerayla çek'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_pickCoverImage(ImageSource.camera));
              },
            ),
            if (_coverImagePath != null)
              ListTile(
                key: const Key('remove_group_cover'),
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: const Text('Kapak fotoğrafını kaldır'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_removeCoverImage());
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showTemporarySettingsMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmGroupAction(
    BuildContext context, {
    required bool deleteGroup,
  }) async {
    final debtSummary = ref
        .read(groupDebtSummaryProvider(group.id))
        .valueOrNull;
    final unsettledBalances = debtSummary?.balances.where(
      (balance) => balance.netAmountInMinor != 0,
    );
    final hasUnsettledBalance = deleteGroup
        ? unsettledBalances?.isNotEmpty ?? false
        : unsettledBalances?.any(
                (balance) =>
                    balance.userId ==
                    ref.read(authSessionControllerProvider).user?.id,
              ) ??
              false;
    if (hasUnsettledBalance) {
      _showTemporarySettingsMessage(
        context,
        deleteGroup
            ? 'Grubu silmeden önce tüm grup borçlarını kapatın.'
            : 'Gruptan ayrılmadan önce bakiyenizi kapatın.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: Key(deleteGroup ? 'delete_group_dialog' : 'leave_group_dialog'),
        title: Text(deleteGroup ? 'Grubu sil' : 'Gruptan ayrıl'),
        content: Text(
          deleteGroup
              ? 'Grup, Gruplarım listesinden kaldırılacak. Finansal geçmiş güvenlik için korunacak. Devam etmek istiyor musunuz?'
              : 'Grup listenizden kaldırılacak. Harcama geçmişiniz korunacak. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: Key(
              deleteGroup
                  ? 'confirm_delete_group_button'
                  : 'confirm_leave_group_button',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(deleteGroup ? 'Grubu sil' : 'Gruptan ayrıl'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !context.mounted) return;

    try {
      final repository = ref.read(groupRepositoryProvider);
      if (deleteGroup) {
        await repository.archiveGroup(group.id);
      } else {
        await repository.leaveGroup(group.id);
      }

      ref.invalidate(groupsProvider);
      ref.invalidate(groupDetailProvider(group.id));
      ref.invalidate(groupExpensesProvider(group.id));
      ref.invalidate(groupDebtSummaryProvider(group.id));
      ref.invalidate(groupSettlementsProvider(group.id));

      if (!mounted || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/groups');
      messenger.showSnackBar(
        SnackBar(
          content: Text(deleteGroup ? 'Grup silindi.' : 'Gruptan ayrıldınız.'),
        ),
      );
    } catch (error) {
      if (!mounted || !context.mounted) return;
      _showTemporarySettingsMessage(
        context,
        groupUserMessage(
          error,
          fallbackMessage: deleteGroup
              ? 'Grup silinemedi. Lütfen tekrar deneyin.'
              : 'Gruptan ayrılamadınız. Lütfen tekrar deneyin.',
        ),
      );
    }
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    try {
      final selection = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (selection == null) return;

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final coversDirectory = Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}group_covers',
      );
      await coversDirectory.create(recursive: true);
      final extensionIndex = selection.path.lastIndexOf('.');
      final extension = extensionIndex >= 0
          ? selection.path.substring(extensionIndex)
          : '.jpg';
      final destination = File(
        '${coversDirectory.path}${Platform.pathSeparator}${group.id}$extension',
      );
      final previousPath = _coverImagePath;
      await File(selection.path).copy(destination.path);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_coverPreferenceKey, destination.path);
      if (previousPath != null && previousPath != destination.path) {
        final previousFile = File(previousPath);
        if (await previousFile.exists()) await previousFile.delete();
      }
      if (mounted) setState(() => _coverImagePath = destination.path);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kapak fotoğrafı eklenemedi: $error')),
      );
    }
  }

  Future<void> _removeCoverImage() async {
    final path = _coverImagePath;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_coverPreferenceKey);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (mounted) setState(() => _coverImagePath = null);
  }

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
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _AddExpenseBottomSheet(
        onCamera: () {
          Navigator.of(sheetContext).pop();
          _openGroupOcr(context, source: 'camera');
        },
        onGallery: () {
          Navigator.of(sheetContext).pop();
          _openGroupOcr(context, source: 'gallery');
        },
        onManual: () {
          Navigator.of(sheetContext).pop();
          _openFastSplit(context, ref, currentUserId);
        },
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

  void _openGroupOcr(BuildContext context, {String? source}) {
    final query = source == null ? '' : '?source=$source';
    context.push(
      '/groups/${Uri.encodeComponent(group.id)}/ocr$query',
      extra: group,
    );
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
              const SnackBar(
                content: Text('Davet bağlantısı e-posta ile gönderildi.'),
              ),
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
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
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

const _orange = Color(0xFFFF5A26);
const _green = Color(0xFF10B981);

class _GroupSettingsBottomSheet extends StatefulWidget {
  const _GroupSettingsBottomSheet({
    required this.groupName,
    required this.currency,
    required this.isOwner,
    required this.notificationsEnabled,
    required this.onEditGroup,
    required this.onGroupPhoto,
    required this.onInviteMember,
    required this.onNotificationsChanged,
    required this.onCurrency,
    required this.onLeaveGroup,
    required this.onDeleteGroup,
  });

  final String groupName;
  final String currency;
  final bool isOwner;
  final bool notificationsEnabled;
  final VoidCallback onEditGroup;
  final VoidCallback onGroupPhoto;
  final VoidCallback onInviteMember;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onCurrency;
  final VoidCallback onLeaveGroup;
  final VoidCallback onDeleteGroup;

  @override
  State<_GroupSettingsBottomSheet> createState() =>
      _GroupSettingsBottomSheetState();
}

class _GroupSettingsBottomSheetState extends State<_GroupSettingsBottomSheet> {
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text(
              'Grup Ayarları',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.groupName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Grup yönetimi',
              children: [
                ListTile(
                  key: const Key('edit_group_settings'),
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Grup bilgilerini düzenle'),
                  subtitle: const Text('Grup adı ve simgesi'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _closeAndRun(widget.onEditGroup),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('group_photo_settings'),
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Grup fotoğrafı'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _closeAndRun(widget.onGroupPhoto),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('manage_group_members'),
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text('Üyeleri yönet ve davet et'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _closeAndRun(widget.onInviteMember),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Tercihler',
              children: [
                SwitchListTile(
                  key: const Key('group_notifications_switch'),
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Bildirimler'),
                  subtitle: const Text('Grup masraf bildirimleri'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    widget.onNotificationsChanged(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('group_currency_settings'),
                  leading: const Icon(Icons.currency_exchange_rounded),
                  title: const Text('Varsayılan para birimi'),
                  subtitle: Text(_currencyLabel(widget.currency)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _closeAndRun(widget.onCurrency),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Tehlikeli bölge',
              titleColor: colors.error,
              children: [
                if (!widget.isOwner)
                  ListTile(
                    key: const Key('leave_group_settings'),
                    leading: Icon(Icons.logout_rounded, color: colors.error),
                    title: Text(
                      'Gruptan ayrıl',
                      style: TextStyle(color: colors.error),
                    ),
                    onTap: () => _closeAndRun(widget.onLeaveGroup),
                  ),
                if (widget.isOwner) ...[
                  ListTile(
                    key: const Key('delete_group_settings'),
                    leading: Icon(Icons.delete_outline, color: colors.error),
                    title: Text(
                      'Grubu sil',
                      style: TextStyle(color: colors.error),
                    ),
                    subtitle: const Text(
                      'Listeden kaldırır, finansal geçmişi korur',
                    ),
                    onTap: () => _closeAndRun(widget.onDeleteGroup),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _closeAndRun(VoidCallback callback) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  String _currencyLabel(String currency) => switch (currency.toUpperCase()) {
    'TRY' => 'TRY (₺)',
    'USD' => 'USD (\$)',
    'EUR' => 'EUR (€)',
    _ => currency.toUpperCase(),
  };
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.titleColor,
  });

  final String title;
  final List<Widget> children;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    ],
  );
}

class _GroupHeaderSection extends StatelessWidget {
  const _GroupHeaderSection({
    required this.group,
    required this.coverImagePath,
    required this.settleUpDate,
    required this.onSelectSettleUpDate,
    required this.onBack,
    required this.onSettings,
  });

  final GroupDetail group;
  final String? coverImagePath;
  final DateTime? settleUpDate;
  final VoidCallback onSelectSettleUpDate;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final hasCover = coverImagePath?.isNotEmpty == true;
    return SizedBox(
      height: 258,
      child: Stack(
        children: [
          if (hasCover)
            Positioned.fill(
              child: Image.file(
                File(coverImagePath!),
                key: const Key('group_cover_image'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hasCover
                      ? const [
                          Color(0xC90F2B3E),
                          Color(0xA6143D4C),
                          Color(0xD9121212),
                        ]
                      : const [
                          Color(0xFF0F2B3E),
                          Color(0xFF143D4C),
                          Color(0xFF121212),
                        ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: _HeaderPattern()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Geri',
                        onPressed: onBack,
                      ),
                      _CircleIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: 'Ayarlar',
                        onPressed: onSettings,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _GroupAvatar(
                        groupName: group.name,
                        imageUrl: group.imageUrl,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          group.name,
                          key: const Key('group_detail_name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _HeaderChip(
                          key: const Key('settle_up_date_chip'),
                          icon: Icons.calendar_today_outlined,
                          label: settleUpDate == null
                              ? 'Ödeme tarihi ekle'
                              : 'Ödeme: ${_formatDate(settleUpDate!)}',
                          outlined: true,
                          onTap: onSelectSettleUpDate,
                        ),
                        const SizedBox(width: 10),
                        _HeaderChip(
                          key: const Key('group_detail_member_count'),
                          icon: Icons.people_outline,
                          label: '${group.memberCount} kişi',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.groupName, required this.imageUrl});

  final String groupName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final icon = _groupIconForName(groupName);
    final initial = groupName.trim().isEmpty
        ? '?'
        : groupName.trim().characters.first.toUpperCase();

    return Container(
      key: const Key('group_detail_avatar'),
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF1FB69C).withValues(alpha: .24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .24)),
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: imageUrl?.trim().isNotEmpty == true
            ? Image.network(
                imageUrl!,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _GroupAvatarFallback(icon: icon, initial: initial),
              )
            : _GroupAvatarFallback(icon: icon, initial: initial),
      ),
    );
  }
}

class _GroupAvatarFallback extends StatelessWidget {
  const _GroupAvatarFallback({required this.icon, required this.initial});

  final IconData? icon;
  final String initial;

  @override
  Widget build(BuildContext context) => Center(
    child: icon != null
        ? Icon(icon, color: Colors.white, size: 31)
        : Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
  );
}

IconData? _groupIconForName(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('ev') || normalized.contains('bursa')) {
    return Icons.home_rounded;
  }
  if (normalized.contains('gezi') || normalized.contains('tatil')) {
    return Icons.flight_rounded;
  }
  if (normalized.contains('yemek') || normalized.contains('restoran')) {
    return Icons.restaurant_rounded;
  }
  return null;
}

class _HeaderPattern extends StatelessWidget {
  const _HeaderPattern();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _HousePatternPainter());
}

class _HousePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    final path = Path()
      ..moveTo(size.width * .08, size.height * .34)
      ..lineTo(size.width * .42, 0)
      ..lineTo(size.width * .78, size.height * .30)
      ..lineTo(size.width * .67, size.height * .30)
      ..lineTo(size.width * .67, size.height)
      ..lineTo(size.width * .22, size.height)
      ..lineTo(size.width * .22, size.height * .30)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .38,
        size.height * .55,
        size.width * .18,
        size.height * .45,
      ),
      Paint()..color = Colors.black.withValues(alpha: .08),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .55),
    shape: const CircleBorder(),
    child: IconButton(
      icon: Icon(icon, color: Colors.white),
      tooltip: tooltip,
      onPressed: onPressed,
    ),
  );
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    super.key,
    required this.icon,
    required this.label,
    this.outlined = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .38),
    shape: StadiumBorder(
      side: outlined
          ? const BorderSide(color: _green, width: 1.2)
          : BorderSide.none,
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({
    required this.debtAsync,
    required this.group,
    required this.currentUserId,
  });
  final AsyncValue<DebtSummary> debtAsync;
  final GroupDetail group;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) => debtAsync.maybeWhen(
    data: (summary) {
      final balance = summary.balances
          .where((item) => item.userId == currentUserId)
          .firstOrNull;
      final amount = balance?.netAmountInMinor ?? 0;
      final isDirectBalance = group.members.length == 2;
      final other =
          group.members
              .where((member) => member.userId != currentUserId)
              .firstOrNull
              ?.displayName ??
          'grup üyesi';
      final owes = amount < 0;
      return Text.rich(
        TextSpan(
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(
              text: amount == 0
                  ? 'Tüm hesaplar kapalı'
                  : owes
                  ? isDirectBalance
                        ? "$other'ye borcunuz: "
                        : 'Gruba borcunuz: '
                  : isDirectBalance
                  ? "$other'den alacağınız: "
                  : 'Gruptan alacağınız: ',
            ),
            if (amount != 0)
              TextSpan(
                text: _formatTl(amount.abs()),
                style: TextStyle(
                  color: owes ? _orange : _green,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      );
    },
    orElse: () => const SizedBox(height: 24),
  );
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onSettleUp,
    required this.onCharts,
    required this.onBalances,
  });
  final VoidCallback? onSettleUp;
  final VoidCallback onCharts;
  final VoidCallback? onBalances;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        FilledButton(
          onPressed: onSettleUp,
          style: FilledButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 22),
          ),
          child: const Text('Ödeme yap'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onCharts,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          icon: const Icon(Icons.diamond, color: Color(0xFF9B5DE5)),
          label: const Text('Grafikler'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          key: const Key('open_debt_summary_button'),
          onPressed: onBalances,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 22),
          ),
          child: const Text('Bakiyeler'),
        ),
      ],
    ),
  );
}

class _GroupDetailLoadingState extends StatelessWidget {
  const _GroupDetailLoadingState();
  @override
  Widget build(BuildContext context) => const SafeArea(
    key: Key('group_detail_loading'),
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _ShimmerBlock(height: 210),
          SizedBox(height: 24),
          _ShimmerBlock(height: 26),
          SizedBox(height: 28),
          _ShimmerBlock(height: 68),
          SizedBox(height: 14),
          _ShimmerBlock(height: 68),
        ],
      ),
    ),
  );
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
    ),
  );
}

String _formatTl(int amountInMinor) => amountInMinor.toTLDisplay;

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.${date.year}';

class _AddExpenseBottomSheet extends StatelessWidget {
  const _AddExpenseBottomSheet({
    required this.onCamera,
    required this.onGallery,
    required this.onManual,
  });
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Bölüştürme Türünü Seç',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Masrafı nasıl eklemek istediğinizi seçin.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _AddExpenseOption(
            key: const Key('select_scan_receipt_button'),
            icon: Icons.camera_alt_outlined,
            title: 'Fiş Tara',
            subtitle: 'Kamerayla çekin ve otomatik okutun',
            onTap: onCamera,
          ),
          const SizedBox(height: 10),
          _AddExpenseOption(
            key: const Key('select_gallery_receipt_button'),
            icon: Icons.photo_library_outlined,
            title: 'Galeriden Seç',
            subtitle: 'Cihazınızdaki bir fişi okutun',
            onTap: onGallery,
          ),
          const SizedBox(height: 10),
          _AddExpenseOption(
            key: const Key('select_fast_split_button'),
            icon: Icons.edit_outlined,
            title: 'Manuel Ekle',
            subtitle: 'Masraf bilgilerini kendiniz girin',
            onTap: onManual,
          ),
        ],
      ),
    ),
  );
}

class _AddExpenseOption extends StatelessWidget {
  const _AddExpenseOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(16),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _green.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _green),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    ),
  );
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
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
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
  return groupUserMessage(
    error,
    fallbackMessage: 'Masraf değişikliği kaydedilemedi. Lütfen tekrar deneyin.',
  );
}

class _GroupExpensesList extends StatelessWidget {
  const _GroupExpensesList({
    required this.expensesAsync,
    required this.currentUserId,
    required this.members,
    required this.onRetry,
    required this.canMutate,
    required this.onEdit,
    required this.onDelete,
  });

  final AsyncValue<List<GroupExpense>> expensesAsync;
  final String? currentUserId;
  final List<GroupMember> members;
  final VoidCallback onRetry;
  final bool Function(GroupExpense expense) canMutate;
  final Future<void> Function(GroupExpense expense) onEdit;
  final Future<void> Function(GroupExpense expense) onDelete;
  @override
  Widget build(BuildContext context) {
    return expensesAsync.when(
      loading: () => const Column(
        children: [
          _ShimmerBlock(height: 72),
          SizedBox(height: 12),
          _ShimmerBlock(height: 72),
          SizedBox(height: 12),
          _ShimmerBlock(height: 72),
        ],
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  'Henüz masraf yok',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'İlk ortak masrafı ekleyebilirsiniz.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }
        final sorted = [...expenses]
          ..sort(
            (a, b) => DateTime.parse(
              b.expenseDate,
            ).compareTo(DateTime.parse(a.expenseDate)),
          );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildExpenseWidgets(context, sorted),
        );
      },
    );
  }

  String _monthKey(GroupExpense expense) {
    final date = DateTime.parse(expense.expenseDate).toLocal();
    return '${date.year}-${date.month}';
  }

  String _monthLabel(GroupExpense expense) {
    final date = DateTime.parse(expense.expenseDate).toLocal();
    return '${_months[date.month - 1]} ${date.year}';
  }

  List<Widget> _buildExpenseWidgets(
    BuildContext context,
    List<GroupExpense> expenses,
  ) {
    final widgets = <Widget>[];
    String? previousMonth;
    for (final expense in expenses) {
      final month = _monthKey(expense);
      if (month != previousMonth) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Text(
              _monthLabel(expense),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        previousMonth = month;
      }
      widgets
        ..add(
          _ExpenseListItem(
            expense: expense,
            currentUserId: currentUserId,
            members: members,
            canMutate: canMutate(expense),
            onEdit: () => unawaited(onEdit(expense)),
            onDelete: () => unawaited(onDelete(expense)),
          ),
        )
        ..add(const SizedBox(height: 8));
    }
    return widgets;
  }
}

const _months = <String>[
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];
const _shortMonths = <String>[
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];

class _ExpenseListItem extends StatelessWidget {
  const _ExpenseListItem({
    required this.expense,
    required this.currentUserId,
    required this.members,
    required this.canMutate,
    required this.onEdit,
    required this.onDelete,
  });
  final GroupExpense expense;
  final String? currentUserId;
  final List<GroupMember> members;
  final bool canMutate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(expense.expenseDate).toLocal();
    final payer = members
        .where((member) => member.userId == expense.payerUserId)
        .firstOrNull;
    final userShare = expense.shares
        .where((share) => share.userId == currentUserId)
        .firstOrNull;
    final userPaid = expense.payerUserId == currentUserId;
    final isLent = userPaid;
    final balanceAmount = isLent
        ? expense.totalAmountInMinor - (userShare?.amountInMinor ?? 0)
        : userShare?.amountInMinor ?? 0;
    final isSettled = balanceAmount == 0;
    final balanceColor = isSettled
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : isLent
        ? _green
        : _orange;

    return Material(
      key: Key('group_expense_${expense.id}'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: canMutate ? () => _showActions(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 45,
                child: Column(
                  children: [
                    Text(
                      _shortMonths[date.month - 1],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      date.day.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 58,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${userPaid ? 'Siz' : payer?.displayName ?? 'Üye'} ödedi: ${_formatTl(expense.totalAmountInMinor)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isSettled
                        ? 'hesap kapalı'
                        : isLent
                        ? 'alacağınız'
                        : 'borcunuz',
                    style: TextStyle(
                      color: isSettled
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : isLent
                          ? const Color(0xFF9FE3CE)
                          : const Color(0xFFE88B6B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTl(balanceAmount),
                    style: TextStyle(
                      color: balanceColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (canMutate)
                PopupMenuButton<_ExpenseAction>(
                  key: Key('group_expense_actions_${expense.id}'),
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  onSelected: (action) =>
                      action == _ExpenseAction.edit ? onEdit() : onDelete(),
                  itemBuilder: (_) => _actionItems,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<_ExpenseAction>> get _actionItems => [
    PopupMenuItem(
      key: Key('edit_group_expense_${expense.id}'),
      value: _ExpenseAction.edit,
      child: const Text('Düzenle'),
    ),
    PopupMenuItem(
      key: Key('delete_group_expense_${expense.id}'),
      value: _ExpenseAction.delete,
      enabled: !expense.isFinanciallyLocked,
      child: Text(
        expense.isFinanciallyLocked ? 'Sil (finansal olarak kilitli)' : 'Sil',
      ),
    ),
  ];

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<_ExpenseAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Düzenle'),
              onTap: () => Navigator.pop(context, _ExpenseAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(
                expense.isFinanciallyLocked
                    ? 'Sil (finansal olarak kilitli)'
                    : 'Sil',
              ),
              enabled: !expense.isFinanciallyLocked,
              onTap: expense.isFinanciallyLocked
                  ? null
                  : () => Navigator.pop(context, _ExpenseAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == _ExpenseAction.edit) onEdit();
    if (action == _ExpenseAction.delete) onDelete();
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

class _AddMemberSheet extends ConsumerStatefulWidget {
  const _AddMemberSheet({required this.canChooseAdmin, required this.onSubmit});

  final bool canChooseAdmin;
  final Future<void> Function(String email, GroupRole role) onSubmit;

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
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
                'Davet bağlantısı bu e-posta adresine gönderilir ve 24 saat geçerlidir.',
              ),
              _FriendPicker(
                onPick: (friend) =>
                    setState(() => _emailController.text = friend.email),
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
                      child: Text('Yönetici'),
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

class _FriendPicker extends ConsumerWidget {
  const _FriendPicker({required this.onPick});

  final ValueChanged<FriendSummary> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider).valueOrNull;
    if (friends == null || friends.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          key: const Key('group_invitation_friend_picker'),
          scrollDirection: Axis.horizontal,
          itemCount: friends.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final friend = friends[index];
            return GestureDetector(
              key: Key('friend_picker_option_${friend.userId}'),
              onTap: () => onPick(friend),
              child: SizedBox(
                width: 60,
                child: Column(
                  children: [
                    AvatarBadge(avatarId: friend.avatarId, radius: 22),
                    const SizedBox(height: 4),
                    Text(
                      friend.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final GroupRole role;

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      GroupRole.owner => 'Sahip',
      GroupRole.admin => 'Yönetici',
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
