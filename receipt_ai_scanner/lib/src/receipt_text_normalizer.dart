typedef ReceiptTextLogger = void Function(String message);

/// Removes OCR spacing noise while preserving meaningful line boundaries.
String normalizeReceiptText(String rawText) {
  return rawText
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
      .where((line) => line.isNotEmpty)
      .join('\n');
}

/// Normalizes OCR output and writes it to the local debug console.
String normalizeAndLogReceiptText(
  String rawText, {
  required ReceiptTextLogger logger,
}) {
  final normalizedText = normalizeReceiptText(rawText);
  logger('[ReceiptScanner] Normalize edilmiş OCR metni:\n$normalizedText');

  return normalizedText;
}
