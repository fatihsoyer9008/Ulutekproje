import 'dart:math' as math;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../domain/savings_goal_insights.dart';

const journeyBackground = AppColors.canvas;
const journeySurface = AppColors.surface;
const journeySurfaceLight = AppColors.mint;
const journeyAccent = AppColors.primary;
const journeyGold = Color(0xFFFFC24B);

class SavingsJourneyGoal {
  const SavingsJourneyGoal({
    required this.title,
    required this.currentAmountInMinor,
    required this.targetAmountInMinor,
    required this.icon,
    required this.color,
  });

  final String title;
  final int currentAmountInMinor;
  final int targetAmountInMinor;
  final IconData icon;
  final Color color;

  double get progress {
    if (targetAmountInMinor <= 0) return 0;

    return (currentAmountInMinor / targetAmountInMinor).clamp(0.0, 1.0);
  }

  int get level => calculateSavingsGoalLevel(
    amountInMinor: currentAmountInMinor,
    targetAmountInMinor: targetAmountInMinor,
  );
}

class SavingsJourneyScreen extends ConsumerStatefulWidget {
  const SavingsJourneyScreen({super.key, required this.goal, this.onAddMoney});

  final SavingsJourneyGoal goal;
  final Future<int?> Function()? onAddMoney;

  @override
  ConsumerState<SavingsJourneyScreen> createState() =>
      _SavingsJourneyScreenState();
}

class _SavingsJourneyScreenState extends ConsumerState<SavingsJourneyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _capsuleController;
  late final AnimationController _coinController;
  late final AnimationController _entranceController;

  late final Animation<double> _capsuleJump;

  late int _currentAmountInMinor;
  int _levelCelebrationId = 0;

  @override
  void initState() {
    super.initState();
    _currentAmountInMinor = widget.goal.currentAmountInMinor;

    _capsuleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );

    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );

    _capsuleJump = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: -18.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -18.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 62,
      ),
    ]).animate(_capsuleController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _capsuleController.dispose();
    _coinController.dispose();
    _entranceController.dispose();

    super.dispose();
  }

  SavingsJourneyGoal get _visibleGoal => SavingsJourneyGoal(
    title: widget.goal.title,
    currentAmountInMinor: _currentAmountInMinor,
    targetAmountInMinor: widget.goal.targetAmountInMinor,
    icon: widget.goal.icon,
    color: widget.goal.color,
  );

  Future<void> _handleAddMoney() async {
    final addedAmountInMinor = await widget.onAddMoney?.call();

    if (!mounted || addedAmountInMinor == null || addedAmountInMinor <= 0) {
      return;
    }

    final previousGoal = _visibleGoal;
    Future<void> playCoinFeedback(Duration delay) async {
      await Future<void>.delayed(delay);

      if (!mounted) return;

      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    }

    final nextAmountInMinor = math
        .min(
          widget.goal.targetAmountInMinor,
          _currentAmountInMinor + addedAmountInMinor,
        )
        .toInt();

    final transition = calculateSavingsGoalLevelTransition(
      previousAmountInMinor: previousGoal.currentAmountInMinor,
      currentAmountInMinor: nextAmountInMinor,
      targetAmountInMinor: widget.goal.targetAmountInMinor,
    );

    setState(() {
      _currentAmountInMinor = nextAmountInMinor;
    });
    _coinController.forward(from: 0);
    await Future.wait([
      playCoinFeedback(const Duration(milliseconds: 450)),
      playCoinFeedback(const Duration(milliseconds: 600)),
      playCoinFeedback(const Duration(milliseconds: 750)),
    ]);

    if (!mounted) return;

    _capsuleController.forward(from: 0);
    if (transition.didLevelUp) {
      setState(() {
        _levelCelebrationId++;
      });
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tebrikler! ${transition.currentLevel}. seviyeye ulaştın.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _visibleGoal;
    final user = ref.watch(authSessionControllerProvider).user;
    final avatarSource = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email ?? 'U');
    final avatarInitial = avatarSource.isEmpty
        ? 'U'
        : avatarSource.substring(0, 1).toUpperCase();

    final currency = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    final remainingAmountInMinor = math.max(
      0,
      goal.targetAmountInMinor - goal.currentAmountInMinor,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF061216) : journeyBackground,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF061216) : journeyBackground,
        foregroundColor: isDark ? const Color(0xFFF4FBFA) : AppColors.ink,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kumbara'),
              SizedBox(height: 2),
              Text(
                'Hedefine adım adım',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isDark ? const Color(0xFFB8CED1) : AppColors.muted,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              FadeTransition(
            opacity: reduceMotion
                ? const AlwaysStoppedAnimation(1)
                : CurvedAnimation(
                    parent: _entranceController,
                    curve: Curves.easeOutCubic,
                  ),
            child: SlideTransition(
              position: reduceMotion
                  ? const AlwaysStoppedAnimation(Offset.zero)
                  : Tween<Offset>(
                      begin: const Offset(0, .035),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _entranceController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  children: [
                _GoalSummaryCard(
                  goal: goal,
                  currentAmountInMinor: goal.currentAmountInMinor,
                  targetAmountInMinor: goal.targetAmountInMinor,
                  remainingAmountInMinor: remainingAmountInMinor,
                  currency: currency,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                _SavingsCapsule(
                  progress: goal.progress,
                  jump: _capsuleJump,
                  coinDrop: _coinController,
                  isDark: isDark,
                ),
                const SizedBox(height: 18),
                _MilestonePath(
                  progress: goal.progress,
                  avatarInitial: avatarInitial,
                  celebrationId: _levelCelebrationId,
                ),
                const SizedBox(height: 28),
                _JourneyTipCard(isDark: isDark),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onAddMoney == null
                        ? null
                        : _handleAddMoney,
                    style: isDark
                        ? FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF78EFE5),
                            foregroundColor: const Color(0xFF062020),
                          )
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Birikim Ekle'),
                  ),
                ),
                  ],
                ),
              ),
              ),
              ),
              Positioned.fill(
                child: Center(
                  child: _CenterConfettiBurst(
                    celebrationId: _levelCelebrationId,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _JourneyTipCard extends StatelessWidget {
  const _JourneyTipCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10272D) : AppColors.mintLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? const Color(0xFF20D7D2) : journeyAccent).withValues(alpha: .34),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up_rounded,
            color: isDark ? const Color(0xFF20D7D2) : journeyAccent,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Düzenli küçük birikimler, büyük hedefleri gerçeğe dönüştürür.',
              style: TextStyle(
                color: isDark ? const Color(0xFFE6F4F5) : AppColors.ink,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({
    required this.goal,
    required this.currentAmountInMinor,
    required this.targetAmountInMinor,
    required this.remainingAmountInMinor,
    required this.currency,
    required this.isDark,
  });

  final SavingsJourneyGoal goal;
  final int currentAmountInMinor;
  final int targetAmountInMinor;
  final int remainingAmountInMinor;
  final NumberFormat currency;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF163139), Color(0xFF0B1A20)]
              : const [AppColors.surface, AppColors.mintLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF20D7D2).withValues(alpha: .65) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF000000).withValues(alpha: .35)
                : AppColors.primary.withValues(alpha: .10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                    color: goal.color.withValues(alpha: .16),
                  border: Border.all(
                    color: goal.color.withValues(alpha: .40),
                  ),
                ),
                child: Icon(goal.icon, color: goal.color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF20D7D2).withValues(alpha: .14)
                      : AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF20D7D2).withValues(alpha: .7)
                        : AppColors.primary.withValues(alpha: .25),
                  ),
                ),
                child: Text(
                  '%${(goal.progress * 100).round()}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF20D7D2) : AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${currency.format(currentAmountInMinor / 100)} / ${currency.format(targetAmountInMinor / 100)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isDark ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            tween: Tween(end: goal.progress),
            builder: (context, progress, _) => ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                color: isDark ? const Color(0xFF20D7D2) : AppColors.primary,
                backgroundColor: isDark
                    ? const Color(0xFF1B3038)
                    : journeySurfaceLight,
                semanticsLabel: 'Hedef ilerlemesi',
                semanticsValue: '%${(progress * 100).round()}',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${currency.format(remainingAmountInMinor / 100)} kaldı',
              style: TextStyle(
                color: isDark ? const Color(0xFFB8CED1) : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsCapsule extends StatelessWidget {
  const _SavingsCapsule({
    required this.progress,
    required this.jump,
    required this.coinDrop,
    required this.isDark,
  });

  final double progress;
  final Animation<double> jump;
  final Animation<double> coinDrop;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 246,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: Listenable.merge([jump, coinDrop]),
        builder: (context, child) {
          final coinAnimationProgress = coinDrop.value;
          final fallProgress = Curves.easeInCubic.transform(coinAnimationProgress);
          final coinTop = -42 + (fallProgress * 115);

          final fadeProgress = ((coinAnimationProgress - .78) / .22)
              .clamp(0.0, 1.0)
              .toDouble();
          final opacity = 1 - Curves.easeOut.transform(fadeProgress);

          return RepaintBoundary(
            child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, jump.value),
                child: Semantics(
                    label: 'Birikim kavanozu, %${(this.progress * 100).round()} dolu',
                    image: true,
                    child: Image.asset(
                      isDark
                          ? 'assets/images/savings/journey_savings_vault.png'
                          : 'assets/images/savings/journey_savings_vault_light.png',
                      height: isDark ? 246 : 238,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                ),
              ),

              for (var index = 0; index < 3; index++)
                _DroppingCoin(progress: coinDrop.value, index: index),
              if (coinAnimationProgress > 0 && coinAnimationProgress < 1)
                Positioned(
                  top: coinTop,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: .12 * (1 - coinAnimationProgress),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE08A), Color(0xFFFFB300)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFF0B8),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x99FFB300), blurRadius: 10),
                          ],
                        ),
                        child: const Text(
                          '₺',
                          style: TextStyle(
                            color: Color(0xFF704500),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            ),
          );
        },
      ),
    );
  }
}

class _MilestonePath extends StatelessWidget {
  const _MilestonePath({
    required this.progress,
    required this.avatarInitial,
    required this.celebrationId,
  });

  final int celebrationId;
  final double progress;
  final String avatarInitial;

  @override
  Widget build(BuildContext context) {
    const milestones = [20, 40, 60, 80, 100];
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxWidth / 9;
        final journeyStep = ((safeProgress * 100) - 20)
            .clamp(0.0, 80.0)
            .toDouble();
        final avatarEnd = unit * (.5 + ((journeyStep / 20) * 2));

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(end: avatarEnd),
          builder: (context, avatarCenter, child) {
            final avatarLeft = (avatarCenter - 24)
                .clamp(0.0, math.max(0.0, constraints.maxWidth - 48))
                .toDouble();

            return SizedBox(
              height: 106,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MilestoneRoadPainter(
                        progress: safeProgress,
                        inactiveColor: colors.outlineVariant,
                        activeColor: journeyAccent,
                      ),
                    ),
                  ),
                  for (var index = 0; index < milestones.length; index++)
                    Positioned(
                      left: ((constraints.maxWidth - 40) * index / 4),
                      top: _milestoneOffsets[index],
                      child: _Milestone(
                        percentage: milestones[index],
                        isCompleted: safeProgress >= milestones[index] / 100,
                      ),
                    ),

                  Positioned(
                    top: -28,
                    left: avatarCenter - 60,
                    child: _LevelConfettiBurst(celebrationId: celebrationId),
                  ),

                  Positioned(
                    top: 2,
                    left: avatarLeft,
                    child: _JourneyAvatar(
                      initial: avatarInitial,
                      celebrationId: celebrationId,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

const _milestoneOffsets = [20.0, 8.0, 25.0, 10.0, 20.0];

class _MilestoneRoadPainter extends CustomPainter {
  const _MilestoneRoadPainter({
    required this.progress,
    required this.inactiveColor,
    required this.activeColor,
  });

  final double progress;
  final Color inactiveColor;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    const nodeRadius = 20.0;
    final points = List<Offset>.generate(5, (index) {
      final x = nodeRadius + ((size.width - nodeRadius * 2) * index / 4);
      return Offset(x, _milestoneOffsets[index] + nodeRadius);
    });
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      final middleX = (start.dx + end.dx) / 2;
      path.cubicTo(middleX, start.dy, middleX, end.dy, end.dx, end.dy);
    }

    final track = Paint()
      ..color = inactiveColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, track);

    final metrics = path.computeMetrics().toList(growable: false);
    if (metrics.isEmpty || progress <= 0) return;
    final activePath = metrics.first.extractPath(0, metrics.first.length * progress);
    final active = Paint()
      ..color = activeColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(activePath, active);
  }

  @override
  bool shouldRepaint(covariant _MilestoneRoadPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.activeColor != activeColor;
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.percentage, required this.isCompleted});

  final int percentage;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = percentage == 100
        ? Icons.flag_rounded
        : Icons.star_outline_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted ? journeyAccent : colors.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted ? journeyAccent : colors.outlineVariant,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : icon,
            size: 21,
            color: isCompleted ? const Color(0xFF062020) : colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '%$percentage',
          style: TextStyle(
            color: isCompleted ? journeyAccent : colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _JourneyAvatar extends StatefulWidget {
  const _JourneyAvatar({required this.initial, required this.celebrationId});

  final String initial;
  final int celebrationId;

  @override
  State<_JourneyAvatar> createState() => _JourneyAvatarState();
}

class _JourneyAvatarState extends State<_JourneyAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.22), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 1.22, end: 1), weight: 55),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _JourneyAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.celebrationId != widget.celebrationId) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: journeyAccent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: journeyAccent.withValues(alpha: .45),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          widget.initial,
          style: const TextStyle(
            color: Color(0xFF062020),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DroppingCoin extends StatelessWidget {
  const _DroppingCoin({required this.progress, required this.index});

  final double progress;
  final int index;

  @override
  Widget build(BuildContext context) {
    const delays = [0.0, 0.18, 0.36];
    const horizontalOffsets = [-5.0, 0.0, 5.0];

    final delayedProgress = ((progress - delays[index]) / .55)
        .clamp(0.0, 1.0)
        .toDouble();

    if (progress < delays[index] || delayedProgress >= 1) {
      return const SizedBox.shrink();
    }

    final fallProgress = Curves.easeInCubic.transform(delayedProgress);
    final coinTop = -42 + (fallProgress * 115);
    final fadeProgress = ((delayedProgress - .84) / .16)
        .clamp(0.0, 1.0)
        .toDouble();

    return Positioned(
      top: coinTop,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.center,
        child: Transform.translate(
          offset: Offset(horizontalOffsets[index], 0),
          child: Opacity(
            opacity: 1 - Curves.easeOut.transform(fadeProgress),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE08A), Color(0xFFFFB300)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFFFF0B8), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x99FFB300), blurRadius: 10),
                ],
              ),
              child: const Text(
                '₺',
                style: TextStyle(
                  color: Color(0xFF704500),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelConfettiBurst extends StatefulWidget {
  const _LevelConfettiBurst({required this.celebrationId});

  final int celebrationId;

  @override
  State<_LevelConfettiBurst> createState() => _LevelConfettiBurstState();
}

class _CenterConfettiBurst extends StatefulWidget {
  const _CenterConfettiBurst({required this.celebrationId});

  final int celebrationId;

  @override
  State<_CenterConfettiBurst> createState() => _CenterConfettiBurstState();
}

class _CenterConfettiBurstState extends State<_CenterConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CenterConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.celebrationId != widget.celebrationId) {
      setState(() => _visible = true);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    const colors = [
      Color(0xFF20D7D2),
      Color(0xFFFFC24B),
      Color(0xFF6FD7F5),
      Color(0xFFE84C88),
      Color(0xFF9C6BFF),
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = Curves.easeOutCubic.transform(_controller.value);
          final opacity = (1 - _controller.value).clamp(0.0, 1.0).toDouble();
          return SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              children: List.generate(36, (index) {
                final angle = (math.pi * 2 * index) / 36;
                final distance = 22 + (progress * (92 + (index % 5) * 12));
                return Positioned(
                  left: 146 + (math.cos(angle) * distance),
                  top: 146 + (math.sin(angle) * distance),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: angle + progress * 3,
                      child: Container(
                        width: index.isEven ? 7 : 10,
                        height: index.isEven ? 14 : 7,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

class _LevelConfettiBurstState extends State<_LevelConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = false;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 720),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _visible = false);
          }
        });
  }

  @override
  void didUpdateWidget(covariant _LevelConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.celebrationId != widget.celebrationId) {
      setState(() => _visible = true);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    const colors = [
      Color(0xFF20D7D2),
      Color(0xFFFFC24B),
      Color(0xFFE84C88),
      Color(0xFF9C6BFF),
    ];

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = Curves.easeOut.transform(_controller.value);

          return SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(18, (index) {
                final angle = (math.pi * 2 * index) / 18;
                final distance = 12 + (progress * 56);
                final opacity = (1 - progress).clamp(0.0, 1.0).toDouble();

                return Positioned(
                  left: 56 + (math.cos(angle) * distance),
                  top: 56 + (math.sin(angle) * distance),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: angle + progress,
                      child: Container(
                        width: 7,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
