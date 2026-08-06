import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;

/// Builds a high-contrast grayscale variant for thermal receipt OCR.
///
/// This function is top-level so Flutter can run it in a background isolate
/// with [compute], keeping image processing away from the UI thread.
Uint8List enhanceReceiptImage(Uint8List sourceBytes) {
  final decoded = image_lib.decodeImage(sourceBytes);
  if (decoded == null) return sourceBytes;

  var enhanced = image_lib.bakeOrientation(decoded);
  const maxLongEdge = 2400;
  final longEdge = enhanced.width > enhanced.height
      ? enhanced.width
      : enhanced.height;
  if (longEdge > maxLongEdge) {
    final scale = maxLongEdge / longEdge;
    enhanced = image_lib.copyResize(
      enhanced,
      width: (enhanced.width * scale).round(),
      height: (enhanced.height * scale).round(),
      interpolation: image_lib.Interpolation.cubic,
    );
  }

  enhanced = image_lib.grayscale(enhanced);
  enhanced = image_lib.histogramStretch(enhanced, stretchClipRatio: 0.01);
  enhanced = image_lib.adjustColor(enhanced, contrast: 1.22, brightness: 1.03);

  return Uint8List.fromList(image_lib.encodeJpg(enhanced, quality: 95));
}

/// Sunucuya gönderilecek, boyutu optimize edilmiş fiş görseli.
class ReceiptUploadImage {
  const ReceiptUploadImage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

/// Görseli sunucu yüklemesi için JPEG'e dönüştürür, yönünü düzeltir ve
/// uzun kenarını en fazla 1920 piksele indirir.
ReceiptUploadImage prepareReceiptImageForUpload(Uint8List sourceBytes) {
  final decoded = image_lib.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const FormatException('Fiş görseli okunamadı.');
  }

  var optimized = image_lib.bakeOrientation(decoded);

  const maxLongEdge = 1920;
  final longEdge = optimized.width > optimized.height
      ? optimized.width
      : optimized.height;

  if (longEdge > maxLongEdge) {
    final scale = maxLongEdge / longEdge;
    optimized = image_lib.copyResize(
      optimized,
      width: (optimized.width * scale).round(),
      height: (optimized.height * scale).round(),
      interpolation: image_lib.Interpolation.cubic,
    );
  }

  return ReceiptUploadImage(
    bytes: Uint8List.fromList(image_lib.encodeJpg(optimized, quality: 85)),
    mimeType: 'image/jpeg',
    fileName: 'receipt.jpg',
  );
}
