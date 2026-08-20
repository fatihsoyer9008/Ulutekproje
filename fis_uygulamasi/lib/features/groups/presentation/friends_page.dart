import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../avatar/presentation/widgets/avatar_badge.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../data/demo_friend_seed.dart';
import '../domain/friend_models.dart';
import 'widgets/groups_bottom_navigation.dart';

const _teal = Color(0xFF20C5A7);
const _orange = Color(0xFFFF5A26);
const _green = Color(0xFF10B981);

/// Friends tab: same skeleton as [GroupsPage] (dark theme override, header
/// balance row, list, pinned FAB, shared bottom navigation), with people
/// instead of groups. UI-only for now — [createDemoFriendSeed] stands in for
/// `GET /api/v1/friends` until that endpoint is wired up.
class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final friends = createDemoFriendSeed();
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
                  _showComingSoon(context, 'Arama yakında eklenecek.'),
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'Arkadaş ekle',
              onPressed: () =>
                  _showComingSoon(context, 'Arkadaş ekleme yakında eklenecek.'),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _FriendsOverview(friends: friends),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('add_friend_expense_button'),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
          onPressed: () =>
              _showComingSoon(context, 'Harcama ekleme yakında eklenecek.'),
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
          onActivityPressed: () =>
              _showComingSoon(context, 'Aktivite ekranı yakında eklenecek.'),
          onAccountPressed: () => context.push('/profile'),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String message) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
}

class _FriendsOverview extends StatelessWidget {
  const _FriendsOverview({required this.friends});

  final List<FriendSummary> friends;

  @override
  Widget build(BuildContext context) {
    final totalNetInMinor = friends.fold<int>(
      0,
      (sum, friend) => sum + friend.netAmountInMinor,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 104),
      children: [
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Arkadaş ekleme yakında eklenecek.'),
              ),
            ),
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
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arkadaş detayı yakında eklenecek.')),
        ),
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
