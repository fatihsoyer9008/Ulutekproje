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
