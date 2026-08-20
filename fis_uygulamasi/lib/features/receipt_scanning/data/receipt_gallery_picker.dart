import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

class ReceiptGallerySelection {
  const ReceiptGallerySelection({
    required this.rawOcrText,
    required this.imageBytes,
  });

  final String rawOcrText;
  final Uint8List imageBytes;
}

/// Selects, validates and recognizes a receipt with the app's shared services.
Future<ReceiptGallerySelection?> pickReceiptFromGallery({
  ImagePicker? picker,
}) async {
  final image = await (picker ?? ImagePicker()).pickImage(
    source: ImageSource.gallery,
    imageQuality: 100,
  );
  if (image == null) return null;

  final imageBytes = await image.readAsBytes();
  final rawOcrText = await recognizeReceiptImage(image.path);
  return ReceiptGallerySelection(
    rawOcrText: rawOcrText,
    imageBytes: imageBytes,
  );
}

/// Captures a receipt with image_picker and forwards it to the shared OCR
/// recognizer. The temporary camera file is removed after recognition.
Future<String?> captureReceiptWithCamera({ImagePicker? picker}) async {
  final image = await (picker ?? ImagePicker()).pickImage(
    source: ImageSource.camera,
    imageQuality: 100,
    preferredCameraDevice: CameraDevice.rear,
  );
  if (image == null) return null;

  try {
    return await recognizeReceiptImage(image.path);
  } finally {
    final temporaryFile = File(image.path);
    if (await temporaryFile.exists()) await temporaryFile.delete();
  }
}
