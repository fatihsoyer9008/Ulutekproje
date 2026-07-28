import 'package:flutter/material.dart';

/// Shows a non-blocking warning when receipt parsing is not reliable enough.
///
/// Scores are expected to be between 0 and 1. The default threshold of 0.70
/// follows the product requirement for the regex parser fallback.
class ReceiptLowConfidenceWarning extends StatelessWidget {
  const ReceiptLowConfidenceWarning({
    required this.confidenceScore,
    this.threshold = defaultThreshold,
    super.key,
  }) : assert(confidenceScore >= 0 && confidenceScore <= 1),
       assert(threshold >= 0 && threshold <= 1);

  static const defaultThreshold = .70;

  final double confidenceScore;
  final double threshold;

  bool get isLowConfidence => confidenceScore < threshold;

  @override
  Widget build(BuildContext context) {
    if (!isLowConfidence) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Uyarı: Tutar veya kurum adından tam emin olamadık, lütfen kontrol edin',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tutar veya kurum adından tam emin olamadık, lütfen kontrol edin',
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
