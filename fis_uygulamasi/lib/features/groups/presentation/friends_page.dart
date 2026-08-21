import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../avatar/presentation/widgets/avatar_badge.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../data/group_api_failure.dart';
import '../data/group_providers.dart';
import '../domain/friend_models.dart';
import '../domain/group_models.dart';
import 'widgets/groups_bottom_navigation.dart';

const _teal = Color(0xFF20C5A7);
const _orange = Color(0xFFFF5A26);
const _green = Color(0xFF10B981);

/// Friends tab: same skeleton as [GroupsPage] (dark theme override, header
/// balance row, list, pinned FAB, shared bottom navigation), with people
/// instead of groups.
class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final appTheme = Theme.of(context);
    final isDark = appTheme.brightness == Brightness.dark;
    final pageBackground = isDark
        ? const Color(0xFF202123)
        : appTheme.scaffoldBackgroundColor;

    final pageTheme = isDark
        ? ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: pageBackground,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1FB69C),
              brightness: Brightness.dark,
            ),
          )
        : appTheme;

    return Theme(
      data: pageTheme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: pageBackground,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 48,
          actions: [
            IconButton(
              tooltip: 'Ara',
              onPressed: () =>
                  _showSnackBar(context, 'Arama yakında eklenecek.'),
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'Arkadaş ekle',
              onPressed: () => _showInviteFriendSheet(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: friendsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _FriendsErrorState(
            message: groupUserMessage(
              error,
              fallbackMessage:
                  'Arkadaşlar yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
            ),
            onRetry: () => ref.invalidate(friendsProvider),
          ),
          data: (friends) => _FriendsOverview(
            friends: friends,
            onInviteFriend: () => _showInviteFriendSheet(context, ref),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('add_friend_expense_button'),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
          onPressed: () =>
              _showSnackBar(context, 'Harcama ekleme yakında eklenecek.'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text(
            'Harcama ekle',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBar: GroupsBottomNavigation(
          activeTab: GroupsBottomTab.friends,
          isDark: isDark,
          lightBackgroundColor: pageBackground,
          onGroupsPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/groups');
            }
          },
          onFriendsPressed: () {},
          onActivityPressed: () => context.push('/activity'),
          onAccountPressed: () => context.push('/profile'),
        ),
      ),
    );
  }
}

void _showSnackBar(BuildContext context, String message) =>
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

Future<void> _showInviteFriendSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InviteFriendSheet(
      onSubmit: (email) async {
        await ref.read(friendRepositoryProvider).createInvitation(email: email);
        if (context.mounted) {
          _showSnackBar(context, 'Arkadaşlık daveti gönderildi.');
        }
      },
    ),
  );
}

class _InviteFriendSheet extends StatefulWidget {
  const _InviteFriendSheet({required this.onSubmit});

  final Future<void> Function(String email) onSubmit;

  @override
  State<_InviteFriendSheet> createState() => _InviteFriendSheetState();
}

class _InviteFriendSheetState extends State<_InviteFriendSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
                'Arkadaş Ekle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Arkadaşlık daveti bu e-posta adresine gönderilecektir.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('friend_invitation_email_field'),
                controller: _emailController,
                autofocus: true,
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
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('submit_friend_invitation_button'),
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
      await widget.onSubmit(_emailController.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = groupUserMessage(
          error,
          fallbackMessage: 'Davet gönderilemedi. Lütfen tekrar deneyin.',
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _FriendsOverview extends StatelessWidget {
  const _FriendsOverview({required this.friends, required this.onInviteFriend});

  final List<FriendSummary> friends;
  final VoidCallback onInviteFriend;

  @override
  Widget build(BuildContext context) {
    final totalNetInMinor = friends.fold<int>(
      0,
      (sum, friend) => sum + friend.netAmountInMinor,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 104),
      children: [
        const _PendingInvitationsSection(),
        Row(
          children: [
            Expanded(child: _OverallBalance(netAmountInMinor: totalNetInMinor)),
            IconButton(
              tooltip: 'Filtrele ve sırala',
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (friends.isEmpty)
          const _FriendsEmptyState()
        else ...[
          for (final friend in friends) ...[
            _FriendCard(friend: friend),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 10),
        ],
        Center(
          child: OutlinedButton.icon(
            key: const Key('add_more_friends_button'),
            onPressed: onInviteFriend,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Daha fazla arkadaş ekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              side: const BorderSide(color: _teal),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverallBalance extends StatelessWidget {
  const _OverallBalance({required this.netAmountInMinor});

  final int netAmountInMinor;

  @override
  Widget build(BuildContext context) {
    final amount = 'TL${formatMinorAsTurkishLira(netAmountInMinor.abs())}';
    final owes = netAmountInMinor < 0;

    return Text.rich(
      TextSpan(
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        children: [
          if (netAmountInMinor == 0)
            const TextSpan(text: 'Genel bakiye: herkesle hesabınız kapalı')
          else ...[
            TextSpan(
              text: owes
                  ? 'Genel bakiye, borcunuz '
                  : 'Genel bakiye, alacağınız ',
            ),
            TextSpan(
              text: amount,
              style: TextStyle(color: owes ? _orange : _green),
            ),
          ],
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend});

  final FriendSummary friend;

  @override
  Widget build(BuildContext context) {
    final amount = friend.netAmountInMinor.abs();
    final owes = friend.netAmountInMinor < 0;
    final statusLabel = friend.netAmountInMinor == 0
        ? 'dengede'
        : owes
        ? 'borçlusunuz'
        : 'alacaklısınız';
    final statusColor = friend.netAmountInMinor == 0
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : owes
        ? _orange
        : _green;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('friend_card_${friend.userId}'),
        onTap: () =>
            _showSnackBar(context, 'Arkadaş detayı yakında eklenecek.'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              AvatarBadge(avatarId: friend.avatarId, radius: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  friend.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (friend.netAmountInMinor != 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TL${formatMinorAsTurkishLira(amount)}',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              else
                Text(statusLabel, style: TextStyle(color: statusColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsEmptyState extends StatelessWidget {
  const _FriendsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(Icons.person_off_outlined, size: 56, color: _teal),
          const SizedBox(height: 16),
          Text(
            'Henüz arkadaşınız yok',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Ortak harcamalarınızı yönetmek için arkadaş ekleyin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PendingInvitationsSection extends ConsumerWidget {
  const _PendingInvitationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendInvitations =
        ref.watch(pendingFriendInvitationsProvider).valueOrNull ?? const [];
    final groupInvitations =
        ref.watch(pendingGroupInvitationsProvider).valueOrNull ?? const [];
    if (friendInvitations.isEmpty && groupInvitations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bekleyen davetler',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final invitation in friendInvitations) ...[
            _PendingFriendInvitationCard(invitation: invitation),
            const SizedBox(height: 10),
          ],
          for (final invitation in groupInvitations) ...[
            _PendingGroupInvitationCard(invitation: invitation),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PendingFriendInvitationCard extends ConsumerStatefulWidget {
  const _PendingFriendInvitationCard({required this.invitation});

  final PendingFriendInvitation invitation;

  @override
  ConsumerState<_PendingFriendInvitationCard> createState() =>
      _PendingFriendInvitationCardState();
}

class _PendingFriendInvitationCardState
    extends ConsumerState<_PendingFriendInvitationCard> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('pending_friend_invitation_${widget.invitation.id}'),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.invitation.inviterDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' seni arkadaş olarak eklemek istiyor.'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            key: Key('accept_friend_invitation_${widget.invitation.id}'),
            onPressed: _accepting ? null : _accept,
            child: _accepting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kabul et'),
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await ref
          .read(friendRepositoryProvider)
          .acceptInvitationById(widget.invitation.id);
      ref.invalidate(friendsProvider);
      ref.invalidate(pendingFriendInvitationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Arkadaşlık daveti kabul edildi.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              groupUserMessage(
                error,
                fallbackMessage: 'Davet kabul edilemedi. Lütfen tekrar deneyin.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }
}

class _PendingGroupInvitationCard extends ConsumerStatefulWidget {
  const _PendingGroupInvitationCard({required this.invitation});

  final PendingGroupInvitation invitation;

  @override
  ConsumerState<_PendingGroupInvitationCard> createState() =>
      _PendingGroupInvitationCardState();
}

class _PendingGroupInvitationCardState
    extends ConsumerState<_PendingGroupInvitationCard> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('pending_group_invitation_${widget.invitation.id}'),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.invitation.inviterDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' sizi '),
                  TextSpan(
                    text: widget.invitation.groupName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' grubuna davet etti.'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            key: Key('accept_group_invitation_${widget.invitation.id}'),
            onPressed: _accepting ? null : _accept,
            child: _accepting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kabul et'),
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      final member = await ref
          .read(groupRepositoryProvider)
          .acceptInvitationById(widget.invitation.id);
      ref.invalidate(groupsProvider);
      ref.invalidate(groupDetailProvider(member.groupId));
      ref.invalidate(pendingGroupInvitationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.invitation.groupName} grubuna katıldınız.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              groupUserMessage(
                error,
                fallbackMessage: 'Davet kabul edilemedi. Lütfen tekrar deneyin.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }
}

class _FriendsErrorState extends StatelessWidget {
  const _FriendsErrorState({required this.message, required this.onRetry});

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
                'Arkadaşlar yüklenemedi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                key: const Key('friends_error_message'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('friends_retry_button'),
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
