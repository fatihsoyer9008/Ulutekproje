import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../domain/savings_goal_insights.dart';
import 'package:flutter/services.dart';

const journeyBackground = Color(0xFF081217);
const journeySurface = Color(0xFF14242B);
const journeySurfaceLight = Color(0xFF1B3038);
const journeyAccent = Color(0xFF20D7D2);
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
  }

  @override
  void dispose() {
    _capsuleController.dispose();
    _coinController.dispose();

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
    final currentAmount = goal.currentAmountInMinor / 100;
    final targetAmount = goal.targetAmountInMinor / 100;
    final remainingAmount = (targetAmount - currentAmount).clamp(
      0.0,
      targetAmount,
    );

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: journeyAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: journeyBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: journeyBackground,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kumbara'),
              SizedBox(height: 2),
              Text(
                'Hedefine adım adım',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFB8CED1),
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              children: [
                _GoalSummaryCard(
                  goal: goal,
                  currentAmount: currentAmount,
                  targetAmount: targetAmount,
                  remainingAmount: remainingAmount,
                  currency: currency,
                ),
                const SizedBox(height: 20),
                _SavingsCapsule(jump: _capsuleJump, coinDrop: _coinController),
                const SizedBox(height: 18),
                _MilestonePath(
                  progress: goal.progress,
                  avatarInitial: avatarInitial,
                  celebrationId: _levelCelebrationId,
                ),
                const SizedBox(height: 28),
                _JourneyTipCard(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onAddMoney == null
                        ? null
                        : _handleAddMoney,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Birikim Ekle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyTipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: journeySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: journeyAccent.withValues(alpha: .22)),
      ),
      child: const Row(
        children: [
          Icon(Icons.trending_up_rounded, color: journeyAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Düzenli küçük birikimler, büyük hedefleri gerçeğe dönüştürür.',
              style: TextStyle(color: Color(0xFFE6F4F5), height: 1.35),
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
    required this.currentAmount,
    required this.targetAmount,
    required this.remainingAmount,
    required this.currency,
  });

  final SavingsJourneyGoal goal;
  final double currentAmount;
  final double targetAmount;
  final double remainingAmount;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF193038), Color(0xFF101D24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: journeyAccent.withValues(alpha: .38)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                  color: journeyAccent.withValues(alpha: .12),
                  border: Border.all(
                    color: journeyAccent.withValues(alpha: .65),
                  ),
                ),
                child: Icon(goal.icon, color: journeyAccent, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
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
                  color: journeyAccent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: journeyAccent.withValues(alpha: .60),
                  ),
                ),
                child: Text(
                  '%${(goal.progress * 100).round()}',
                  style: const TextStyle(
                    color: journeyAccent,
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
              '${currency.format(currentAmount)} / ${currency.format(targetAmount)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 10,
              color: journeyAccent,
              backgroundColor: journeySurfaceLight,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${currency.format(remainingAmount)} kaldı',
              style: const TextStyle(color: Color(0xFFB8CED1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsCapsule extends StatelessWidget {
  const _SavingsCapsule({required this.jump, required this.coinDrop});

  final Animation<double> jump;
  final Animation<double> coinDrop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 292,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: Listenable.merge([jump, coinDrop]),
        builder: (context, child) {
          final progress = coinDrop.value;
          final fallProgress = Curves.easeInCubic.transform(progress);
          final coinTop = -42 + (fallProgress * 115);

          final fadeProgress = ((progress - .78) / .22)
              .clamp(0.0, 1.0)
              .toDouble();
          final opacity = 1 - Curves.easeOut.transform(fadeProgress);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, jump.value),
                child: Image.asset(
                  'assets/images/savings/journey_savings_vault.png',
                  height: 270,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),

              for (var index = 0; index < 3; index++)
                _DroppingCoin(progress: coinDrop.value, index: index),
              if (progress > 0 && progress < 1)
                Positioned(
                  top: coinTop,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: .12 * (1 - progress),
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
              height: 82,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: [
                      for (
                        var index = 0;
                        index < milestones.length;
                        index++
                      ) ...[
                        Expanded(
                          child: _Milestone(
                            percentage: milestones[index],
                            isCompleted:
                                safeProgress >= milestones[index] / 100,
                          ),
                        ),
                        if (index < milestones.length - 1)
                          Expanded(
                            child: _ProgressSegment(
                              progress:
                                  ((safeProgress - milestones[index] / 100) /
                                          .20)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                              inactiveColor: colors.outlineVariant,
                            ),
                          ),
                      ],
                    ],
                  ),

                  Positioned(
                    top: -28,
                    left: avatarCenter - 60,
                    child: _LevelConfettiBurst(celebrationId: celebrationId),
                  ),

                  Positioned(
                    top: -4,
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

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({required this.progress, required this.inactiveColor});

  final double progress;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: inactiveColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: journeyAccent,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
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
