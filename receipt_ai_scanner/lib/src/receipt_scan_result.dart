import 'dart:typed_data';

/// Yerel OCR sonucunu ve kullanıcının onay verebileceği özgün fiş görselini taşır.
class ReceiptScanResult {
  const ReceiptScanResult({required this.rawOcrText, required this.imageBytes});

  final String rawOcrText;
  final Uint8List imageBytes;
}
