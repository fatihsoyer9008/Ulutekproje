import 'dart:typed_data';
import 'dart:math' as math;

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
  enhanced = _applyClahe(enhanced);

  return Uint8List.fromList(image_lib.encodeJpg(enhanced, quality: 95));
}

const _claheTileSize = 64;
const _claheClipFactor = 3.0;
const _shadowTargetLuminance = 150.0;
const _maximumShadowLift = 42.0;

/// Applies contrast-limited adaptive histogram equalization (CLAHE).
///
/// Every tile receives an independent clipped histogram. Per-pixel values are
/// interpolated between the four neighbouring tile lookup tables so tile
/// borders remain invisible. Dark tiles also receive a bounded luminance lift;
/// bright tiles receive none, preventing highlight clipping.
image_lib.Image _applyClahe(image_lib.Image grayscale) {
  final tilesX = (grayscale.width / _claheTileSize).ceil();
  final tilesY = (grayscale.height / _claheTileSize).ceil();
  final lookupTables = List.generate(
    tilesY,
    (tileY) => List.generate(tilesX, (tileX) {
      final left = tileX * _claheTileSize;
      final top = tileY * _claheTileSize;
      final right = math.min(left + _claheTileSize, grayscale.width);
      final bottom = math.min(top + _claheTileSize, grayscale.height);
      return _buildClaheLookupTable(
        grayscale,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      );
    }),
  );

  final result = image_lib.Image(
    width: grayscale.width,
    height: grayscale.height,
    // JPEG encoder expects RGB channels; one-channel images are interpreted as
    // red-only and lose most of their perceived luminance after decoding.
    numChannels: 3,
  );
  for (var y = 0; y < grayscale.height; y++) {
    final vertical = _tileInterpolation(y, tilesY);
    for (var x = 0; x < grayscale.width; x++) {
      final horizontal = _tileInterpolation(x, tilesX);
      final luminance = grayscale
          .getPixel(x, y)
          .luminance
          .round()
          .clamp(0, 255);
      final topValue = _lerp(
        lookupTables[vertical.lower][horizontal.lower][luminance],
        lookupTables[vertical.lower][horizontal.upper][luminance],
        horizontal.weight,
      );
      final bottomValue = _lerp(
        lookupTables[vertical.upper][horizontal.lower][luminance],
        lookupTables[vertical.upper][horizontal.upper][luminance],
        horizontal.weight,
      );
      final value = _lerp(
        topValue,
        bottomValue,
        vertical.weight,
      ).round().clamp(0, 255);
      result.setPixelRgb(x, y, value, value, value);
    }
  }
  return result;
}

Uint8List _buildClaheLookupTable(
  image_lib.Image image, {
  required int left,
  required int top,
  required int right,
  required int bottom,
}) {
  final histogram = List<int>.filled(256, 0);
  var luminanceSum = 0;
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final luminance = image.getPixel(x, y).luminance.round().clamp(0, 255);
      histogram[luminance]++;
      luminanceSum += luminance;
    }
  }

  final pixelCount = (right - left) * (bottom - top);
  final clipLimit = math.max(
    1,
    (pixelCount * _claheClipFactor / histogram.length).ceil(),
  );
  var excess = 0;
  for (var index = 0; index < histogram.length; index++) {
    if (histogram[index] <= clipLimit) continue;
    excess += histogram[index] - clipLimit;
    histogram[index] = clipLimit;
  }

  final sharedExcess = excess ~/ histogram.length;
  final remainder = excess % histogram.length;
  for (var index = 0; index < histogram.length; index++) {
    histogram[index] += sharedExcess;
  }
  for (var index = 0; index < remainder; index++) {
    histogram[index * histogram.length ~/ remainder]++;
  }

  final averageLuminance = luminanceSum / pixelCount;
  final shadowLift = averageLuminance >= _shadowTargetLuminance
      ? 0.0
      : math.min(
          _maximumShadowLift,
          (_shadowTargetLuminance - averageLuminance) * 0.45,
        );
  final lookupTable = Uint8List(256);
  var cumulative = 0;
  var firstCumulative = 0;
  for (var index = 0; index < histogram.length; index++) {
    cumulative += histogram[index];
    if (firstCumulative == 0 && cumulative > 0) firstCumulative = cumulative;
    final denominator = pixelCount - firstCumulative;
    final equalized = denominator <= 0
        ? index.toDouble()
        : (cumulative - firstCumulative) * 255 / denominator;
    lookupTable[index] = (equalized + shadowLift).round().clamp(0, 255);
  }
  return lookupTable;
}

_TileInterpolation _tileInterpolation(int coordinate, int tileCount) {
  if (tileCount == 1) {
    return const _TileInterpolation(lower: 0, upper: 0, weight: 0);
  }

  final position = (coordinate + 0.5) / _claheTileSize - 0.5;
  final lower = position.floor();
  if (lower < 0) {
    return const _TileInterpolation(lower: 0, upper: 0, weight: 0);
  }
  if (lower >= tileCount - 1) {
    final last = tileCount - 1;
    return _TileInterpolation(lower: last, upper: last, weight: 0);
  }
  return _TileInterpolation(
    lower: lower,
    upper: lower + 1,
    weight: position - lower,
  );
}

double _lerp(num start, num end, double weight) =>
    start + (end - start) * weight;

class _TileInterpolation {
  const _TileInterpolation({
    required this.lower,
    required this.upper,
    required this.weight,
  });

  final int lower;
  final int upper;
  final double weight;
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
