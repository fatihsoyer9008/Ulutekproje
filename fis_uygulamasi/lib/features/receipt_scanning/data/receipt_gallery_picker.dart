import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
Future<ReceiptGallerySelection?> pickReceiptFromGallery() async {
  const imageTypes = XTypeGroup(
    label: 'Görseller',
    extensions: supportedReceiptImageExtensions,
  );
  final image = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[imageTypes],
  );
  if (image == null) return null;

  final imageBytes = await image.readAsBytes();
  final rawOcrText = await recognizeReceiptImage(image.path);
  return ReceiptGallerySelection(
    rawOcrText: rawOcrText,
    imageBytes: imageBytes,
  );
}
