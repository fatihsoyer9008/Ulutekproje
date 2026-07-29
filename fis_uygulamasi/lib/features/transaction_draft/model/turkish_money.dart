import 'package:intl/intl.dart';

final NumberFormat _turkishLiraFormat = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '',
  decimalDigits: 2,
);

/// Converts a Turkish lira value such as `1.234,56` to kuruş.
int? parseTurkishLiraToMinor(String? value) {
  final normalized = value
      ?.trim()
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('₺', '')
      .replaceAll('TL', '');
  if (normalized == null || normalized.isEmpty) return null;

  final match = RegExp(
    r'^(\d{1,3}(?:\.\d{3})*|\d+)(?:,(\d{1,2}))?$',
  ).firstMatch(normalized);
  if (match == null) return null;

  final lira = int.tryParse(match.group(1)!.replaceAll('.', ''));
  if (lira == null) return null;

  final fraction = match.group(2) ?? '';
  final kurus = fraction.isEmpty
      ? 0
      : int.parse(fraction.length == 1 ? '${fraction}0' : fraction);
  return (lira * 100) + kurus;
}

String formatMinorAsTurkishLira(int amountInMinor) {
  return _turkishLiraFormat.format(amountInMinor / 100).trim();
}

int? parseMajorAmountToMinor(Object? value) {
  if (value == null) return null;
  if (value is int) return value * 100;

  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final normalized = text.contains(',') && !text.contains('.')
      ? text.replaceAll(',', '.')
      : text;
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) return null;

  final lira = int.parse(match.group(1)!);
  final fraction = match.group(2) ?? '';
  final kurus = fraction.isEmpty
      ? 0
      : int.parse(fraction.length == 1 ? '${fraction}0' : fraction);
  return (lira * 100) + kurus;
}
/// TL cinsinden tutarı kuruş cinsine çevirir.
///
/// Örnek:
/// ```dart
/// final amountInMinor = 12.50.toKurus; // 1250
/// ```
///
/// Kayan nokta gösteriminden kaynaklanan değerleri doğru kuruşa
/// dönüştürmek için [round] kullanılır.
extension TurkishLiraDoubleExtension on double {
  int get toKurus {
    if (!isFinite) {
      throw ArgumentError.value(
        this,
        'amount',
        'Para tutarı sonlu bir sayı olmalıdır.',
      );
    }

    return (this * 100).round();
  }
}
