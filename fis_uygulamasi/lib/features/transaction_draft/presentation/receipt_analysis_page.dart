import 'dart:async';
import 'dart:math' as math;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class ReceiptAnalysisPage extends StatefulWidget {
  const ReceiptAnalysisPage({super.key});

  @override
  State<ReceiptAnalysisPage> createState() => _ReceiptAnalysisPageState();
}

class _ReceiptAnalysisPageState extends State<ReceiptAnalysisPage>
    with SingleTickerProviderStateMixin {
  static const _messages = <String>[
    'Fişiniz inceleniyor...',
    'Rakamlar tek tek doğrulanıyor...',
    'Satırlar anlam kazanıyor...',
    'Harcamalarınız düzenleniyor...',
    'Son dokunuşlar yapılıyor...',
  ];

  late final AnimationController _animationController;
  Timer? _messageTimer;
  var _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      key: const Key('receipt_analysis_page'),
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReceiptScanAnimation(animation: _animationController),
                  const SizedBox(height: 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _messages[_messageIndex],
                      key: ValueKey(_messageIndex),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Yapay zekâ fiş detaylarını sizin için hazırlıyor.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  const _AnimatedDots(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ReceiptScanAnimation extends StatelessWidget {
  const _ReceiptScanAnimation({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 142,
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = (math.sin(animation.value * math.pi * 2) + 1) / 2;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 112 + (pulse * 20),
              height: 112 + (pulse * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mint.withValues(alpha: 0.45 - pulse * 0.2),
              ),
            ),
            child!,
            Positioned(
              top: 43 + (animation.value * 55),
              child: Container(
                width: 62,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.primary,
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      child: Container(
        width: 86,
        height: 104,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A16483C),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(
          Icons.receipt_long_rounded,
          color: AppColors.primary,
          size: 48,
        ),
      ),
    ),
  );
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final phase = (_controller.value - index * 0.18) % 1;
        final strength = (math.sin(phase * math.pi * 2) + 1) / 2;
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.3 + strength * 0.7),
          ),
        );
      }),
    ),
  );
}
