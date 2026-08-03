import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

typedef CapturedReceiptTextRecognizer =
    Future<String> Function(String imagePath);
typedef CapturedReceiptFileDeleter = Future<void> Function(String imagePath);

/// Runs OCR for an app-owned camera capture and removes the source afterward.
///
/// This must only be used for files returned by [CameraController.takePicture].
/// User-selected gallery files are not owned by the scanner and must not be
/// deleted.
Future<String> recognizeAndDeleteCapturedReceiptPhoto(
  XFile photo, {
  required CapturedReceiptTextRecognizer recognize,
  CapturedReceiptFileDeleter deleteFile = deleteCapturedReceiptFile,
}) async {
  try {
    return await recognize(photo.path);
  } finally {
    try {
      await deleteFile(photo.path);
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[ReceiptScanner] Orijinal kamera görseli temizlenemedi: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

Future<void> deleteCapturedReceiptFile(String imagePath) async {
  final file = File(imagePath);
  if (await file.exists()) await file.delete();
}
