import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

const int maxReceiptImageBytes = 10 * 1024 * 1024;
const int maxReceiptImagePixels = 25 * 1000 * 1000;
const List<String> supportedReceiptImageExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
];

enum ReceiptImageValidationFailure {
  unsupportedFormat,
  tooLarge,
  tooManyPixels,
  empty,
  corrupt,
}

class ReceiptImageValidationException implements Exception {
  const ReceiptImageValidationException(this.failure, this.message);

  final ReceiptImageValidationFailure failure;
  final String message;

  @override
  String toString() => message;
}

void validateReceiptImageSelection({
  required String imagePath,
  required int byteLength,
}) {
  final extension = _extensionOf(imagePath);
  if (!supportedReceiptImageExtensions.contains(extension)) {
    throw const ReceiptImageValidationException(
      ReceiptImageValidationFailure.unsupportedFormat,
      'Bu dosya formatı desteklenmiyor. Lütfen JPG, JPEG veya PNG seçin.',
    );
  }
  if (byteLength <= 0) {
    throw const ReceiptImageValidationException(
      ReceiptImageValidationFailure.empty,
      'Seçilen görsel dosyası boş. Lütfen başka bir görsel seçin.',
    );
  }
  if (byteLength > maxReceiptImageBytes) {
    throw const ReceiptImageValidationException(
      ReceiptImageValidationFailure.tooLarge,
      'Seçilen görsel 10 MB sınırını aşıyor. Lütfen daha küçük bir görsel seçin.',
    );
  }
}

Future<void> validateReceiptImageBytes({
  required String imagePath,
  required Uint8List bytes,
}) async {
  validateReceiptImageSelection(imagePath: imagePath, byteLength: bytes.length);

  final extension = _extensionOf(imagePath);
  final failureIndex = await compute<List<Object>, int?>(
    _decodeReceiptImage,
    <Object>[extension, bytes],
    debugLabel: 'receipt-image-validation',
  );
  if (failureIndex != null) {
    throw _exceptionFor(ReceiptImageValidationFailure.values[failureIndex]);
  }
}

void validateReceiptImageDimensions({required int width, required int height}) {
  final failure = _dimensionFailure(width: width, height: height);
  if (failure != null) throw _exceptionFor(failure);
}

int? _decodeReceiptImage(List<Object> request) {
  final extension = request[0] as String;
  final bytes = request[1] as Uint8List;
  final decoder = image_lib.findDecoderForData(bytes);
  final hasMatchingFormat = switch (extension) {
    'jpg' || 'jpeg' => decoder is image_lib.JpegDecoder,
    'png' => decoder is image_lib.PngDecoder,
    _ => false,
  };
  if (!hasMatchingFormat) {
    return ReceiptImageValidationFailure.corrupt.index;
  }

  try {
    final info = decoder!.startDecode(bytes);
    if (info == null) return ReceiptImageValidationFailure.corrupt.index;

    final dimensionFailure = _dimensionFailure(
      width: info.width,
      height: info.height,
    );
    if (dimensionFailure != null) return dimensionFailure.index;

    return decoder.decode(bytes) == null
        ? ReceiptImageValidationFailure.corrupt.index
        : null;
  } on Exception {
    return ReceiptImageValidationFailure.corrupt.index;
  }
}

ReceiptImageValidationFailure? _dimensionFailure({
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0) {
    return ReceiptImageValidationFailure.corrupt;
  }
  if (width * height > maxReceiptImagePixels) {
    return ReceiptImageValidationFailure.tooManyPixels;
  }
  return null;
}

ReceiptImageValidationException _exceptionFor(
  ReceiptImageValidationFailure failure,
) => switch (failure) {
  ReceiptImageValidationFailure.unsupportedFormat =>
    const ReceiptImageValidationException(
      ReceiptImageValidationFailure.unsupportedFormat,
      'Bu dosya formatı desteklenmiyor. Lütfen JPG, JPEG veya PNG seçin.',
    ),
  ReceiptImageValidationFailure.tooLarge => const ReceiptImageValidationException(
    ReceiptImageValidationFailure.tooLarge,
    'Seçilen görsel 10 MB sınırını aşıyor. Lütfen daha küçük bir görsel seçin.',
  ),
  ReceiptImageValidationFailure.tooManyPixels =>
    const ReceiptImageValidationException(
      ReceiptImageValidationFailure.tooManyPixels,
      'Seçilen görselin çözünürlüğü çok yüksek. Lütfen 25 megapiksel veya daha düşük bir görsel seçin.',
    ),
  ReceiptImageValidationFailure.empty => const ReceiptImageValidationException(
    ReceiptImageValidationFailure.empty,
    'Seçilen görsel dosyası boş. Lütfen başka bir görsel seçin.',
  ),
  ReceiptImageValidationFailure.corrupt =>
    const ReceiptImageValidationException(
      ReceiptImageValidationFailure.corrupt,
      'Seçilen görsel bozuk, okunamıyor veya içeriği uzantısıyla uyuşmuyor.',
    ),
};

String _extensionOf(String path) {
  final fileName = path.split(RegExp(r'[/\\]')).last;
  final dotIndex = fileName.lastIndexOf('.');
  return dotIndex < 0 ? '' : fileName.substring(dotIndex + 1).toLowerCase();
}
