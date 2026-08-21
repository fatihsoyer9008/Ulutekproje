import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../avatar/presentation/widgets/avatar_badge.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../data/group_api_failure.dart';
import '../data/group_providers.dart';
import '../domain/group_activity_models.dart';
import 'widgets/groups_bottom_navigation.dart';

const _teal = Color(0xFF20C5A7);
const _orange = Color(0xFFFF7A45);
const _green = Color(0xFF13A976);

class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key, this.activities, this.referenceTime});

  /// Optional injection point for widget tests and isolated design previews.
  final List<GroupActivityEntry>? activities;
  final DateTime? referenceTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = referenceTime ?? DateTime.now();
    final injectedEntries = activities;
    final activityAsync = injectedEntries == null
        ? ref.watch(groupActivityFeedProvider)
        : AsyncValue<List<GroupActivityEntry>>.data(injectedEntries);
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
              seedColor: _teal,
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
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hareket arama yakında eklenecek.'),
                ),
              ),
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: activityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ActivityErrorState(
            message: groupUserMessage(
              error,
              fallbackMessage:
                  'Hareketler yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
            ),
            onRetry: () => ref.invalidate(groupActivityFeedProvider),
          ),
          data: (items) {
            final entries = List<GroupActivityEntry>.of(items)
              ..sort(
                (left, right) => right.occurredAt.compareTo(left.occurredAt),
              );
            return _ActivityFeed(entries: entries, now: now);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('add_activity_expense_button'),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
          onPressed: () => context.go('/groups'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text(
            'Add expense',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBar: GroupsBottomNavigation(
          activeTab: GroupsBottomTab.activity,
          isDark: isDark,
          lightBackgroundColor: pageBackground,
          onGroupsPressed: () => context.go('/groups'),
          onFriendsPressed: () => context.go('/friends'),
          onActivityPressed: () {},
          onAccountPressed: () => context.push('/profile'),
        ),
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.entries, required this.now});

  final List<GroupActivityEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const Key('activity_feed'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Recent activity',
              key: const Key('activity_page_title'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ),
        if (entries.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _ActivityEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 104),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _ActivityRow(
                key: Key('activity_${entries[index].id}'),
                entry: entries[index],
                now: now,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({super.key, required this.entry, required this.now});

  final GroupActivityEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectColor = switch (entry.balanceEffect) {
      GroupActivityBalanceEffect.receivable => _green,
      GroupActivityBalanceEffect.payable => _orange,
      GroupActivityBalanceEffect.neutral => colors.onSurfaceVariant,
    };

    return Semantics(
      label: _semanticLabel(entry),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityIcon(type: entry.type, actorAvatarId: entry.actorAvatarId),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActivitySentence(entry: entry),
                const SizedBox(height: 4),
                Text(
                  _balanceLabel(entry),
                  key: Key('activity_balance_${entry.id}'),
                  style: TextStyle(
                    color: effectColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _relativeTimestamp(entry.occurredAt, now),
                  key: Key('activity_date_${entry.id}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySentence extends StatelessWidget {
  const _ActivitySentence({required this.entry});

  final GroupActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge;
    final boldStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);
    final actor = entry.isCurrentUserActor ? 'You' : entry.actorName;

    return Text.rich(
      key: Key('activity_message_${entry.id}'),
      TextSpan(
        style: baseStyle,
        children: switch (entry.type) {
          GroupActivityType.expenseAdded => [
            TextSpan(text: actor, style: boldStyle),
            const TextSpan(text: ' added '),
            TextSpan(text: '“${entry.subject}”', style: boldStyle),
            const TextSpan(text: ' in '),
            TextSpan(text: '“${entry.groupName}”', style: boldStyle),
            const TextSpan(text: '.'),
          ],
          GroupActivityType.expenseUpdated => [
            TextSpan(text: actor, style: boldStyle),
            const TextSpan(text: ' updated '),
            TextSpan(text: '“${entry.subject}”', style: boldStyle),
            const TextSpan(text: ' in '),
            TextSpan(text: '“${entry.groupName}”', style: boldStyle),
            const TextSpan(text: '.'),
          ],
          GroupActivityType.expenseDeleted => [
            TextSpan(text: actor, style: boldStyle),
            const TextSpan(text: ' deleted '),
            TextSpan(text: '“${entry.subject}”', style: boldStyle),
            const TextSpan(text: ' from '),
            TextSpan(text: '“${entry.groupName}”', style: boldStyle),
            const TextSpan(text: '.'),
          ],
          GroupActivityType.groupCreated => [
            TextSpan(text: actor, style: boldStyle),
            const TextSpan(text: ' created the group '),
            TextSpan(text: '“${entry.groupName}”', style: boldStyle),
            const TextSpan(text: '.'),
          ],
          GroupActivityType.settlementRecorded => [
            TextSpan(text: actor, style: boldStyle),
            const TextSpan(text: ' recorded a settlement in '),
            TextSpan(text: '“${entry.groupName}”', style: boldStyle),
            const TextSpan(text: '.'),
          ],
          GroupActivityType.memberJoined ||
          GroupActivityType.invitationAccepted => [
            TextSpan(text: actor, style: boldStyle),
            const TextSpan(text: ' added '),
            TextSpan(text: entry.subject, style: boldStyle),
            const TextSpan(text: ' to '),
            TextSpan(text: '“${entry.groupName}”', style: boldStyle),
            const TextSpan(text: '.'),
          ],
          GroupActivityType.memberLeft => [
            TextSpan(text: entry.subject, style: boldStyle),
            const TextSpan(text: ' left '),
            TextSpan(text: '“${entry.groupName}”', style: boldStyle),
            const TextSpan(text: '.'),
          ],
        },
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.type, required this.actorAvatarId});

  final GroupActivityType type;
  final String? actorAvatarId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainIcon = switch (type) {
      GroupActivityType.expenseAdded => Icons.receipt_long_outlined,
      GroupActivityType.expenseUpdated => Icons.edit_note_rounded,
      GroupActivityType.expenseDeleted => Icons.delete_outline_rounded,
      GroupActivityType.groupCreated => Icons.groups_outlined,
      GroupActivityType.settlementRecorded => Icons.handshake_outlined,
      GroupActivityType.memberJoined ||
      GroupActivityType.invitationAccepted => Icons.person_add_alt_1_outlined,
      GroupActivityType.memberLeft => Icons.person_remove_outlined,
    };

    return SizedBox(
      width: 58,
      height: 62,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 50,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2B2D30) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF44474B)
                      : const Color(0xFFD9E1DE),
                ),
              ),
              child: Icon(mainIcon, size: 27),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              key: const Key('activity_actor_avatar'),
              width: 26,
              height: 26,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: AvatarBadge(avatarId: actorAvatarId, radius: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 104),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 58, color: _teal),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Group expenses and settlements will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityErrorState extends StatelessWidget {
  const _ActivityErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 104),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'Activity could not be loaded',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              key: const Key('activity_error_message'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('activity_retry_button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _balanceLabel(GroupActivityEntry entry) {
  if (entry.balanceEffect == GroupActivityBalanceEffect.neutral ||
      entry.amountInMinor == 0) {
    return 'You do not owe anything';
  }
  final amount =
      '${entry.currency == 'TRY' ? 'TL' : entry.currency ?? ''}'
      '${formatMinorAsTurkishLira(entry.amountInMinor.abs())}';
  return entry.balanceEffect == GroupActivityBalanceEffect.receivable
      ? 'You get back $amount'
      : 'You owe $amount';
}

String _relativeTimestamp(DateTime occurredAt, DateTime now) {
  final localOccurredAt = occurredAt.toLocal();
  final localNow = now.toLocal();
  final occurredDate = DateTime(
    localOccurredAt.year,
    localOccurredAt.month,
    localOccurredAt.day,
  );
  final currentDate = DateTime(localNow.year, localNow.month, localNow.day);
  final dayDifference = currentDate.difference(occurredDate).inDays;
  final time = DateFormat('HH:mm').format(localOccurredAt);

  if (dayDifference <= 0) return 'Today at $time';
  if (dayDifference == 1) return '1 day ago, $time';
  if (dayDifference < 14) return '$dayDifference days ago, $time';
  return DateFormat('MMM d, HH:mm').format(localOccurredAt);
}

String _semanticLabel(GroupActivityEntry entry) =>
    '${entry.actorName}, ${entry.subject}, ${entry.groupName}, '
    '${_balanceLabel(entry)}';
