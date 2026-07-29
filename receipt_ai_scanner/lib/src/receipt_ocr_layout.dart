import 'dart:math' as math;

/// OCR line plus its position in the captured image.
class ReceiptOcrLine {
  const ReceiptOcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.confidence,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double? confidence;

  double get height => math.max(1, bottom - top);
  double get centerY => (top + bottom) / 2;
}

/// Restores receipt reading order from ML Kit line bounding boxes.
///
/// ML Kit's aggregate text can list independent blocks out of visual order.
/// Receipt labels and their right-aligned amounts are therefore flattened,
/// clustered into visual rows, and ordered from left to right.
String arrangeReceiptOcrLines(Iterable<ReceiptOcrLine> sourceLines) {
  final lines =
      sourceLines.where((line) => line.text.trim().isNotEmpty).toList()
        ..sort((a, b) {
          final topOrder = a.top.compareTo(b.top);
          return topOrder != 0 ? topOrder : a.left.compareTo(b.left);
        });
  if (lines.isEmpty) return '';

  final rows = <_ReceiptOcrRow>[];
  for (final line in lines) {
    _ReceiptOcrRow? closestRow;
    var closestDistance = double.infinity;
    for (final row in rows.reversed) {
      final distance = (row.centerY - line.centerY).abs();
      final tolerance = math.max(row.averageHeight, line.height) * 0.6;
      if (distance <= tolerance && distance < closestDistance) {
        closestRow = row;
        closestDistance = distance;
      }
      if (row.centerY < line.centerY - tolerance * 2) break;
    }

    if (closestRow == null) {
      rows.add(_ReceiptOcrRow(line));
    } else {
      closestRow.add(line);
    }
  }

  rows.sort((a, b) => a.top.compareTo(b.top));
  return rows.map((row) => row.text).join('\n');
}

/// Scores whether OCR text contains useful receipt evidence.
///
/// Score is used only to choose between original and enhanced local OCR
/// passes. It is not the financial parser's confidence score.
double receiptOcrQualityScore(String rawText, {double? lineConfidence}) {
  final text = rawText.trim();
  if (text.isEmpty) return 0;

  final upper = text.toUpperCase();
  final lines = text.split('\n').where((line) => line.trim().isNotEmpty).length;
  final characters = text.replaceAll(RegExp(r'\s'), '').length;
  final hasDate =
      upper.contains('TARİH') ||
      upper.contains('TARIH') ||
      RegExp(r'\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b').hasMatch(upper);
  final hasTotal =
      upper.contains('TOPLAM') ||
      upper.contains('ÖDENECEK') ||
      upper.contains('ODENECEK');
  final hasAmount = RegExp(r'(?:[*₺]?\s*)\d{1,6}[.,]\d{2}\b').hasMatch(upper);
  final hasMerchantSignal = RegExp(
    r'\b(?:A[.ŞS]\.?|MARKET|MAĞAZA|MAGAZA|MGZ|TİC|TIC)\b',
  ).hasMatch(upper);

  var score = 0.0;
  score += math.min(characters / 180, 1) * 0.2;
  score += math.min(lines / 12, 1) * 0.15;
  if (hasDate) score += 0.15;
  if (hasTotal) score += 0.2;
  if (hasAmount) score += 0.15;
  if (hasMerchantSignal) score += 0.1;
  if (RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(upper) && RegExp(r'\d').hasMatch(upper)) {
    score += 0.05;
  }
  if (lineConfidence != null) {
    score = score * 0.85 + lineConfidence.clamp(0, 1) * 0.15;
  }
  return score.clamp(0, 1);
}

class _ReceiptOcrRow {
  _ReceiptOcrRow(ReceiptOcrLine first) : _lines = [first];

  final List<ReceiptOcrLine> _lines;

  double get top => _lines.map((line) => line.top).reduce(math.min);
  double get centerY =>
      _lines.map((line) => line.centerY).reduce((a, b) => a + b) /
      _lines.length;
  double get averageHeight =>
      _lines.map((line) => line.height).reduce((a, b) => a + b) / _lines.length;

  void add(ReceiptOcrLine line) => _lines.add(line);

  String get text {
    _lines.sort((a, b) => a.left.compareTo(b.left));
    return _lines.map((line) => line.text.trim()).join(' ');
  }
}
