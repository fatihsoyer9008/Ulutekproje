import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/widgets/auth_widgets.dart';
import '../data/onboarding_preferences.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _pageCount = 3;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isFinishing = false;

  bool get _isLastPage => _currentPage == _pageCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    try {
      await ref.read(onboardingPreferencesProvider).complete();
    } on Exception {
      // Depolama geçici olarak kullanılamasa da kullanıcı uygulamaya girebilmeli.
    }

    if (mounted) context.go('/welcome');
  }

  void _skip() => unawaited(_finish());

  void _next() {
    if (_isLastPage) {
      unawaited(_finish());
      return;
    }
    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  _OnboardingHeader(
                    showSkip: !_isLastPage,
                    onSkip: _isFinishing ? null : _skip,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                      },
                      children: const [
                        _OnboardingSlide(
                          illustration: _ReceiptScanIllustration(),
                          eyebrow: 'HIZLI KAYIT',
                          title: 'Fişini tara, gerisini EconBuddy halletsin.',
                          description:
                              'Kamera veya galeriden fişini ekle; kurum, tarih ve tutar bilgilerini saniyeler içinde hazırla.',
                        ),
                        _OnboardingSlide(
                          illustration: _FinanceInsightsIllustration(),
                          eyebrow: 'NET TAKİP',
                          title: 'Paranın nereye gittiğini net gör.',
                          description:
                              'Gelir ve giderlerini tek yerde izle, kategorilerini karşılaştır ve bütçeni kontrol altında tut.',
                        ),
                        _OnboardingSlide(
                          illustration: _GroupSplitIllustration(),
                          eyebrow: 'KOLAY PAYLAŞIM',
                          title: 'Ortak masrafları zahmetsizce bölüş.',
                          description:
                              'Fişteki ürünleri kişilere ata, adil paylaşımı hesapla ve grup borçlarını kolayca takip et.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PageIndicator(
                    pageCount: _pageCount,
                    currentPage: _currentPage,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const Key('onboarding_primary_button'),
                    onPressed: _isFinishing ? null : _next,
                    icon: _isFinishing
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Icon(
                            _isLastPage
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(
                      _isLastPage ? "EconBuddy'yi Keşfet" : 'Devam Et',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Verilerin senin kontrolünde. Misafir olarak da başlayabilirsin.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        const AppLogo(size: 40),
        const SizedBox(width: 10),
        Text('EconBuddy', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        SizedBox(
          width: 64,
          child: showSkip
              ? TextButton(
                  key: const Key('onboarding_skip_button'),
                  onPressed: onSkip,
                  child: const Text('Atla'),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.illustration,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final Widget illustration;
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationHeight = (constraints.maxHeight * .52)
            .clamp(210.0, 340.0)
            .toDouble();

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: illustrationHeight, child: illustration),
                const SizedBox(height: 22),
                Text(
                  eyebrow,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.pageCount, required this.currentPage});

  final int pageCount;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$pageCount tanıtım sayfasından ${currentPage + 1}. sayfa',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pageCount, (index) {
            final selected = index == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: selected ? 28 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _IllustrationFrame extends StatelessWidget {
  const _IllustrationFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : AppColors.mintLight,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -42,
              right: -32,
              child: _SoftCircle(size: 150, color: scheme.primaryContainer),
            ),
            Positioned(
              left: -28,
              bottom: -52,
              child: _SoftCircle(size: 140, color: scheme.secondaryContainer),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _ReceiptScanIllustration extends StatelessWidget {
  const _ReceiptScanIllustration();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      excludeSemantics: true,
      image: true,
      label: 'Kamera ile taranan dijital fiş çizimi',
      child: _IllustrationFrame(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 164,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withAlpha(23),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: scheme.primary,
                    size: 34,
                  ),
                  const SizedBox(height: 14),
                  _ReceiptLine(widthFactor: .92, color: scheme.onSurface),
                  const SizedBox(height: 8),
                  _ReceiptLine(widthFactor: .72, color: scheme.outline),
                  const SizedBox(height: 8),
                  _ReceiptLine(widthFactor: .84, color: scheme.outline),
                  const SizedBox(height: 14),
                  Divider(color: scheme.outlineVariant, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOPLAM',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        '₺248,50',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 34,
              bottom: 30,
              child: _FloatingIcon(
                icon: Icons.document_scanner_rounded,
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
            ),
            Positioned(
              left: 34,
              top: 34,
              child: _FloatingIcon(
                icon: Icons.auto_awesome_rounded,
                backgroundColor: scheme.tertiaryContainer,
                foregroundColor: scheme.onTertiaryContainer,
                size: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.widthFactor, required this.color});

  final double widthFactor;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

class _FinanceInsightsIllustration extends StatelessWidget {
  const _FinanceInsightsIllustration();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      excludeSemantics: true,
      image: true,
      label: 'Gelir gider grafiği ve bütçe özeti çizimi',
      child: _IllustrationFrame(
        child: Center(
          child: Container(
            width: 244,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withAlpha(23),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Aylık görünüm',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '₺12.480',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 86,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ChartBar(height: 42, color: scheme.primaryContainer),
                      _ChartBar(height: 64, color: scheme.primaryContainer),
                      _ChartBar(height: 52, color: scheme.primaryContainer),
                      _ChartBar(height: 82, color: scheme.primary),
                      _ChartBar(height: 68, color: scheme.primaryContainer),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _LegendDot(color: AppColors.income),
                    const SizedBox(width: 6),
                    const Text('Gelir'),
                    const Spacer(),
                    _LegendDot(color: AppColors.expense),
                    const SizedBox(width: 6),
                    const Text('Gider'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _GroupSplitIllustration extends StatelessWidget {
  const _GroupSplitIllustration();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      excludeSemantics: true,
      image: true,
      label: 'Üç kişi arasında bölüştürülen ortak masraf çizimi',
      child: _IllustrationFrame(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 188,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withAlpha(23),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_2_rounded, color: scheme.primary, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'Akşam Yemeği',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₺1.260,00',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '3 kişiye bölündü',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 26,
              top: 36,
              child: _PersonAvatar(
                initials: 'AY',
                color: scheme.tertiaryContainer,
                foregroundColor: scheme.onTertiaryContainer,
              ),
            ),
            Positioned(
              right: 24,
              top: 46,
              child: _PersonAvatar(
                initials: 'MK',
                color: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
              ),
            ),
            Positioned(
              right: 38,
              bottom: 26,
              child: _PersonAvatar(
                initials: 'SE',
                color: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({
    required this.initials,
    required this.color,
    required this.foregroundColor,
  });

  final String initials;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 54,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(
        color: Theme.of(context).colorScheme.surface,
        width: 4,
      ),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withAlpha(23),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Text(
      initials,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: foregroundColor,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.size = 58,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withAlpha(36),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Icon(icon, color: foregroundColor),
  );
}
