import 'dart:math' as math;

import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/savings/application/savings_goal_notifier.dart';
import '../../features/savings/domain/savings_goal_insights.dart';
import '../../features/savings/domain/savings_money.dart';
import '../models/ui_models.dart';
import '../../features/savings/presentation/savings_journey_screen.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key, this.goals = const []}) : live = false;
  const SavingsScreen.live({super.key}) : goals = null, live = true;

  final List<SavingGoal>? goals;
  final bool live;

  @override
  Widget build(BuildContext context) {
    if (live) return const _LiveSavingsScreen();
    return _SavingsContent(
      goals: [for (final goal in goals!) _GoalView.fromLegacy(goal)],
    );
  }
}

class _LiveSavingsScreen extends ConsumerWidget {
  const _LiveSavingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(activeSavingsOwnerKeyProvider);
    return owner.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        onRetry: () => ref.invalidate(activeSavingsOwnerKeyProvider),
      ),
      data: (ownerKey) {
        final goals = ref.watch(savingsGoalProvider(ownerKey));
        return goals.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadError(
            onRetry: () =>
                ref.read(savingsGoalProvider(ownerKey).notifier).loadGoals(),
          ),
          data: (items) => _SavingsContent(
            goals: [for (final item in items) _GoalView.fromEntity(item)],
            onAdd: (goal) =>
                ref.read(savingsGoalProvider(ownerKey).notifier).addGoal(goal),
            onUpdateAmount: (id, amount) => ref
                .read(savingsGoalProvider(ownerKey).notifier)
                .updateGoalAmount(id, amount),
          ),
        );
      },
    );
  }
}

class _SavingsContent extends StatelessWidget {
  const _SavingsContent({required this.goals, this.onAdd, this.onUpdateAmount});

  final List<_GoalView> goals;
  final Future<void> Function(SavingsGoalEntity goal)? onAdd;
  final Future<void> Function(int id, int amountInMinor)? onUpdateAmount;

  Future<void> _showCreateSheet(BuildContext context) async {
    if (onAdd == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => _CreateSavingsGoalSheet(onSave: onAdd!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return _SavingsEmptyOnboarding(
        onCreateGoal: onAdd == null ? null : () => _showCreateSheet(context),
      );
    }

    final ordered = [...goals]..sort(_compareGoalPriority);
    return Stack(
      children: [
        ListView(
          key: const Key('savings_vertical_list'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
          children: [
            _sectionTitle(context, '🎯', 'Ana Hedef'),
            const SizedBox(height: 12),
            _GoalCard(
              goal: ordered.first,
              featured: true,
              onUpdateAmount: onUpdateAmount,
            ),
            if (ordered.length > 1) ...[
              const SizedBox(height: 26),
              _sectionTitle(context, null, 'Diğer Birikimlerim'),
              const SizedBox(height: 12),
              for (final goal in ordered.skip(1)) ...[
                _GoalCard(goal: goal, onUpdateAmount: onUpdateAmount),
                const SizedBox(height: 12),
              ],
            ],
            const SizedBox(key: Key('savings_bottom_safe_space'), height: 120),
          ],
        ),
        if (onAdd != null) _createFab(context),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String? emoji, String title) =>
      Row(
        children: [
          if (emoji != null) ...[
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      );

  Widget _createFab(BuildContext context) => Positioned(
    right: 20,
    // AppShell'in sağ alttaki AI Asistan FAB'ının üzerinde kalır.
    bottom: 96,
    child: FloatingActionButton.extended(
      key: const Key('add_savings_goal_fab'),
      onPressed: () => _showCreateSheet(context),
      backgroundColor: const Color(0xFF00D7C7),
      foregroundColor: Colors.black,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Yeni Hedef'),
    ),
  );
}

class _SavingsEmptyOnboarding extends StatelessWidget {
  const _SavingsEmptyOnboarding({this.onCreateGoal});

  final VoidCallback? onCreateGoal;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 720;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(28, compact ? 16 : 32, 28, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
              child: Column(
                children: [
                  _SavingsOnboardingIllustration(compact: compact),
                  SizedBox(height: compact ? 20 : 30),
                  const Text(
                    'BİRİKİM HEDEFLERİNİZİ YÖNETİN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Birikim hedeflerinizi yönetin',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mevcut hedeflerinizi takip edin, yeni hedefler belirleyin ve otomatik kuralları özelleştirin.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: compact ? 24 : 34),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('create_first_savings_goal'),
                      onPressed: onCreateGoal,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('HEDEF EKLE'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Verilerin senin kontrolünde. Misafir olarak da başlayabilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SavingsOnboardingIllustration extends StatelessWidget {
  const _SavingsOnboardingIllustration({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 270 : 330,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 142,
              height: 106,
              decoration: const BoxDecoration(
                color: Color(0xFF9DEFD8),
                borderRadius: BorderRadius.only(topRight: Radius.circular(42)),
              ),
            ),
          ),
          const Positioned(
            left: 22,
            top: 36,
            child: _OnboardingAvatar(initials: 'AY', color: Color(0xFFD5EBFC)),
          ),
          const Positioned(
            right: 26,
            top: 48,
            child: _OnboardingAvatar(initials: 'MK', color: Color(0xFFBFE5D7)),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: compact ? 104 : 126,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _OnboardingGoalCard(
                  title: 'Haftalık Tatil\nFonu',
                  icon: Icons.favorite_rounded,
                  progress: .22,
                ),
                _OnboardingGoalCard(
                  title: 'Kişisel Bilgisayar\nHedefi',
                  icon: Icons.laptop_mac_rounded,
                  progress: .35,
                ),
                _OnboardingGoalCard(
                  title: 'Otomatik\nBirikim',
                  icon: Icons.savings_rounded,
                  progress: .72,
                ),
              ],
            ),
          ),
          const Positioned(
            right: 34,
            bottom: 18,
            child: _OnboardingAvatar(initials: 'SE', color: Color(0xFF9DEFD8)),
          ),
        ],
      ),
    ),
  );
}

class _OnboardingGoalCard extends StatelessWidget {
  const _OnboardingGoalCard({
    required this.title,
    required this.icon,
    required this.progress,
  });

  final String title;
  final IconData icon;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    width: 98,
    height: 132,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(color: Color(0x16000000), blurRadius: 12, offset: Offset(0, 5)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const Spacer(),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            color: AppColors.primary,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    ),
  );
}

class _OnboardingAvatar extends StatelessWidget {
  const _OnboardingAvatar({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 58,
    height: 58,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 4),
    ),
    child: Text(
      initials,
      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
    ),
  );
}

class _SavingsManagementHero extends StatelessWidget {
  const _SavingsManagementHero({required this.goals, this.onAddGoal});

  final List<_GoalView> goals;
  final VoidCallback? onAddGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Birikim hedeflerinizi yönetin',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.mintLight, AppColors.mint],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BİRİKİM HEDEFLERİNİZİ YÖNETİN',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 12),
            SizedBox(
              height: 132,
              child: Stack(
                children: [
                  for (var index = 0; index < goals.length; index++)
                    Positioned(
                      left: index == 0 ? 4 : index == 1 ? 96 : 190,
                      top: index == 1 ? 0 : 14,
                      child: TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 420 + (index * 120)),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: .88, end: 1),
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: Opacity(opacity: scale, child: child),
                        ),
                        child: _GoalPreviewCard(goal: goals[index]),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Birikim hedeflerinizi yönetin',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mevcut hedeflerini takip et, yenilerini belirle.',
              style: theme.textTheme.bodyMedium,
            ),
            if (onAddGoal != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAddGoal,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('HEDEF EKLE'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalPreviewCard extends StatelessWidget {
  const _GoalPreviewCard({required this.goal});

  final _GoalView goal;

  @override
  Widget build(BuildContext context) => Container(
    width: 108,
    height: 118,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(color: Color(0x18000000), blurRadius: 10, offset: Offset(0, 4)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(goal.icon, color: goal.color, size: 20),
        const Spacer(),
        Text(
          goal.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: goal.progress,
            minHeight: 5,
            color: goal.color,
            backgroundColor: AppColors.mint,
          ),
        ),
      ],
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    this.featured = false,
    this.onUpdateAmount,
  });

  final _GoalView goal;
  final bool featured;
  final Future<void> Function(int id, int amountInMinor)? onUpdateAmount;
  Future<int?> _showAddMoneySheet(BuildContext context) async {
    if (goal.id == null || onUpdateAmount == null) return null;

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _AddSavingsAmountSheet(
        goal: goal,
        onSave: (amountInMinor) => onUpdateAmount!(
          goal.id!,
          goal.currentAmountInMinor + amountInMinor,
        ),
      ),
    );
  }

  Future<void> _openJourney(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SavingsJourneyScreen(
          goal: SavingsJourneyGoal(
            title: goal.title,
            currentAmountInMinor: goal.currentAmountInMinor,
            targetAmountInMinor: goal.targetAmountInMinor,
            icon: goal.icon,
            color: goal.color,
          ),

          onAddMoney: onUpdateAmount == null || goal.id == null
              ? null
              : () => _showAddMoneySheet(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress;
    final remaining = (goal.target - goal.current)
        .clamp(0, double.infinity)
        .toDouble();
    final colors = _progressColors(goal.color);
    final currency = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    final theme = Theme.of(context);
    final ringSize = featured ? 112.0 : 84.0;
    return Container(
      key: ValueKey('savings_goal_${goal.id ?? goal.title}'),
      padding: EdgeInsets.all(featured ? 20 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? .42 : .68,
        ),
        borderRadius: BorderRadius.circular(featured ? 28 : 24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: .20)
              : Colors.black.withValues(alpha: .06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: colors.last.withValues(alpha: .14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBadge(goal: goal, progress: progress),
          const SizedBox(height: 12),
          Row(
            children: [
              _GradientProgressRing(
                progress: progress,
                size: ringSize,
                colors: colors,
                icon: goal.icon,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (featured
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (goal.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 3),
                      Text(
                        goal.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${currency.format(goal.current)} / ${currency.format(goal.target)}',
                        style:
                            (featured
                                    ? theme.textTheme.headlineSmall
                                    : theme.textTheme.titleLarge)
                                ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GradientLinearProgress(progress: progress, colors: colors),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Kalan: ${currency.format(remaining)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (goal.targetDate != null)
                Text(
                  '•  ${DateFormat('d MMMM y', 'tr_TR').format(goal.targetDate!)}',
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 17, color: colors.first),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _smartSuggestion(goal, remaining),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('open_savings_journey_${goal.id ?? goal.title}'),
              onPressed: () => _openJourney(context),
              icon: const Icon(Icons.route_rounded),
              label: const Text('Hedef Yolculuğunu Gör'),
            ),
          ),
          if (onUpdateAmount != null && goal.id != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('add_money_${goal.id}'),
                onPressed: () => _showAddMoneySheet(context),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.last,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Birikim Ekle'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

int _compareGoalPriority(_GoalView left, _GoalView right) {
  if (left.targetDate == null && right.targetDate == null) {
    return right.progress.compareTo(left.progress);
  }
  if (left.targetDate == null) return 1;
  if (right.targetDate == null) return -1;
  return left.targetDate!.compareTo(right.targetDate!);
}

List<Color> _progressColors(Color accent) => [
  Color.lerp(accent, Colors.white, .22)!,
  Color.lerp(accent, const Color(0xFF00AEEF), .28)!,
];

String _smartSuggestion(_GoalView goal, double remaining) {
  if (remaining <= 0) return 'Harika! Bu hedefe ulaştın.';
  final monthlyInMinor = requiredMonthlySavingsInMinor(
    remainingAmountInMinor: (remaining * 100).round(),
    targetDate: goal.targetDate,
    now: DateTime.now(),
  );
  if (monthlyInMinor != null) {
    return 'Ayda ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2).format(monthlyInMinor / 100)} ekleyerek hedefe zamanında ulaşabilirsin.';
  }
  return 'Düzenli küçük katkılarla hedefini bugünden hızlandırabilirsin.';
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.goal, required this.progress});

  final _GoalView goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final status = calculateSavingsGoalStatus(
      progress: progress,
      createdAt: goal.createdAt,
      targetDate: goal.targetDate,
      now: DateTime.now(),
    );
    final (label, color) = switch (status) {
      SavingsGoalStatus.completed => (
        '🏆 Hedef Tamamlandı',
        const Color(0xFF2EAD67),
      ),
      SavingsGoalStatus.overdue => (
        '⚠️ Hedef Tarihi Geçti',
        const Color(0xFFD14343),
      ),
      SavingsGoalStatus.aheadOfPlan => (
        '🎯 Planın Önündesin',
        const Color(0xFF00AEEF),
      ),
      SavingsGoalStatus.behindPlan => (
        '📌 Planın Gerisindesin',
        const Color(0xFFE0783E),
      ),
      SavingsGoalStatus.deadlineApproaching => (
        '⏳ Zaman Daralıyor',
        const Color(0xFFF59E0B),
      ),
      SavingsGoalStatus.progressingWell => (
        '🔥 Çok İyi Gidiyor',
        const Color(0xFFFF3D81),
      ),
      SavingsGoalStatus.gettingStarted => ('✨ Güzel Bir Başlangıç', goal.color),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GradientProgressRing extends StatelessWidget {
  const _GradientProgressRing({
    required this.progress,
    required this.size,
    required this.colors,
    required this.icon,
  });

  final double progress;
  final double size;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: _GradientRingPainter(
            progress: progress,
            colors: colors,
            trackColor: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .28),
          ),
        ),
        Container(
          width: size * .62,
          height: size * .62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [colors.first.withValues(alpha: .18), Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: size * .30, color: colors.first),
              const SizedBox(height: 1),
              Text(
                '%${(progress * 100).round()}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: size * .12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter({
    required this.progress,
    required this.colors,
    required this.trackColor,
  });

  final double progress;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, track);

    if (progress <= 0) return;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..shader = SweepGradient(colors: colors).createShader(rect);
    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: colors).createShader(rect);
    final sweep = math.pi * 2 * progress;
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, glow);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, foreground);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor;
}

class _GradientLinearProgress extends StatelessWidget {
  const _GradientLinearProgress({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: SizedBox(
      height: 7,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: .30),
              child: const SizedBox.expand(),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                boxShadow: [
                  BoxShadow(color: colors.last, blurRadius: 8, spreadRadius: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddSavingsAmountSheet extends StatefulWidget {
  const _AddSavingsAmountSheet({required this.goal, required this.onSave});

  final _GoalView goal;
  final Future<void> Function(int amountInMinor) onSave;

  @override
  State<_AddSavingsAmountSheet> createState() => _AddSavingsAmountSheetState();
}

class _AddSavingsAmountSheetState extends State<_AddSavingsAmountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _amountInMinor() => parseSavingsAmountInMinor(_controller.text);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_amountInMinor()!);
      if (mounted) Navigator.of(context).pop(_amountInMinor());
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Birikim eklenemedi. Tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
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
            '${widget.goal.title} için birikim ekle',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const Key('add_savings_amount_field'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Eklenecek Tutar',
              prefixText: '₺ ',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
            validator: (_) {
              final amountInMinor = _amountInMinor();
              if (amountInMinor == null || amountInMinor <= 0) {
                return 'Sıfırdan büyük geçerli bir tutar girin.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('confirm_add_savings_amount'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            label: const Text('Birikime Ekle'),
          ),
        ],
      ),
    ),
  );
}

class _CreateSavingsGoalSheet extends StatefulWidget {
  const _CreateSavingsGoalSheet({required this.onSave});
  final Future<void> Function(SavingsGoalEntity goal) onSave;

  @override
  State<_CreateSavingsGoalSheet> createState() =>
      _CreateSavingsGoalSheetState();
}

class _CreateSavingsGoalSheetState extends State<_CreateSavingsGoalSheet> {
  static const _icons = [
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.flight_takeoff_rounded,
    Icons.school_rounded,
    Icons.devices_rounded,
    Icons.favorite_rounded,
  ];
  static const _colors = [
    Color(0xFF00BFAF),
    Color(0xFF4F7CFF),
    Color(0xFF9C6BFF),
    Color(0xFFFF8A4C),
    Color(0xFFE84C88),
    Color(0xFF39A85B),
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialController = TextEditingController();
  DateTime? _targetDate;
  int _iconIndex = 0;
  int _colorIndex = 0;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  int? _parseAmountInMinor(String value) => parseSavingsAmountInMinor(value);

  String? _requiredAmountValidator(String? value) {
    final amount = _parseAmountInMinor(value ?? '');
    if (amount == null || amount <= 0) return 'Geçerli bir hedef tutar girin.';
    return null;
  }

  String? _optionalAmountValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = _parseAmountInMinor(value);
    if (amount == null || amount < 0) {
      return 'Geçerli bir başlangıç tutarı girin.';
    }
    final target = _parseAmountInMinor(_targetController.text);
    if (target != null && amount > target) {
      return 'Başlangıç tutarı hedefi aşamaz.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 30),
    );
    if (selected != null) setState(() => _targetDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final goal = SavingsGoalEntity()
      ..title = _titleController.text.trim()
      ..description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim()
      ..targetAmountInMinor = _parseAmountInMinor(_targetController.text)!
      ..currentAmountInMinor = _parseAmountInMinor(_initialController.text) ?? 0
      ..targetDate = _targetDate
      ..iconCodePoint = _icons[_iconIndex].codePoint
      ..colorHex =
          '#${_colors[_colorIndex].toARGB32().toRadixString(16).substring(2).toUpperCase()}'
      ..createdAt = DateTime.now();
    try {
      await widget.onSave(goal);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hedef kaydedilemedi. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Yeni Birikim Hedefi', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('savings_goal_title'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Hedef Başlığı *',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Hedef başlığı zorunludur.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('savings_goal_target_amount'),
                      controller: _targetController,
                      decoration: const InputDecoration(
                        labelText: 'Hedef Tutar *',
                        prefixText: '₺ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: _requiredAmountValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('savings_goal_initial_amount'),
                      controller: _initialController,
                      decoration: const InputDecoration(
                        labelText: 'Başlangıç',
                        prefixText: '₺ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: _optionalAmountValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _targetDate == null
                      ? 'Hedef Tarihi Seç'
                      : DateFormat('d MMMM y', 'tr_TR').format(_targetDate!),
                ),
              ),
              const SizedBox(height: 18),
              Text('İkon', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(
                  _icons.length,
                  (index) => ChoiceChip(
                    selected: _iconIndex == index,
                    onSelected: (_) => setState(() => _iconIndex = index),
                    avatar: Icon(_icons[index]),
                    label: const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Renk', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: List.generate(
                  _colors.length,
                  (index) => InkWell(
                    onTap: () => setState(() => _colorIndex = index),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _colors[index],
                        shape: BoxShape.circle,
                        border: _colorIndex == index
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: _colorIndex == index
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('save_savings_goal'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Hedefi Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalView {
  const _GoalView(
    this.id,
    this.title,
    this.description,
    this.current,
    this.target,
    this.targetDate,
    this.createdAt,
    this.icon,
    this.color,
  );
  factory _GoalView.fromLegacy(SavingGoal goal) => _GoalView(
    null,
    goal.title,
    null,
    goal.current,
    goal.target,
    null,
    DateTime.fromMillisecondsSinceEpoch(0),
    goal.icon,
    goal.color,
  );
  factory _GoalView.fromEntity(SavingsGoalEntity goal) => _GoalView(
    goal.id,
    goal.title,
    goal.description,
    goal.currentAmountInMinor / 100,
    goal.targetAmountInMinor / 100,
    goal.targetDate,
    goal.createdAt,
    IconData(
      // ignore: non_const_argument_for_const_parameter
      goal.iconCodePoint ?? Icons.savings_rounded.codePoint,
      fontFamily: 'MaterialIcons',
    ),
    _colorFromHex(goal.colorHex),
  );
  final int? id;
  final String title;
  final String? description;
  final double current;
  final double target;
  final DateTime? targetDate;
  final DateTime createdAt;
  final IconData icon;
  final Color color;

  int get currentAmountInMinor => (current * 100).round();
  int get targetAmountInMinor => (target * 100).round();

  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);
}

Color _colorFromHex(String? value) {
  final hex = value?.replaceFirst('#', '');
  final parsed = int.tryParse(hex ?? '', radix: 16);
  return parsed == null ? AppColors.primary : Color(0xFF000000 | parsed);
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Birikim hedefleri yüklenemedi.'),
        const SizedBox(height: 12),
        if (onRetry != null)
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
      ],
    ),
  );
}
