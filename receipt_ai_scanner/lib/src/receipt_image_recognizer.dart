import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_image_preprocessor.dart';
import 'receipt_ocr_layout.dart';
import 'receipt_text_normalizer.dart';

abstract interface class ReceiptImageRecognizer {
  Future<String> recognize(String imagePath);
}

abstract interface class ReceiptOcrEngine {
  Future<ReceiptOcrCandidate> recognize(String imagePath);

  Future<void> close();
}

abstract interface class ReceiptImageWorkspace {
  Future<Uint8List> readSource(String imagePath);

  Future<String> writeTemporaryImage(Uint8List bytes);

  Future<void> deleteTemporaryImage(String imagePath);
}

typedef ReceiptImageEnhancer = Future<Uint8List> Function(Uint8List bytes);
typedef ReceiptOcrEngineFactory = ReceiptOcrEngine Function();

class ReceiptOcrCandidate {
  const ReceiptOcrCandidate({required this.text, required this.score});

  final String text;
  final double score;
}

class OnDeviceReceiptImageRecognizer implements ReceiptImageRecognizer {
  OnDeviceReceiptImageRecognizer({
    required this.createOcrEngine,
    required this.workspace,
    required this.enhanceImage,
  });

  factory OnDeviceReceiptImageRecognizer.mlKit() =>
      OnDeviceReceiptImageRecognizer(
        createOcrEngine: MlKitReceiptOcrEngine.new,
        workspace: FileSystemReceiptImageWorkspace(),
        enhanceImage: _enhanceInBackground,
      );

  final ReceiptOcrEngineFactory createOcrEngine;
  final ReceiptImageWorkspace workspace;
  final ReceiptImageEnhancer enhanceImage;

  @override
  Future<String> recognize(String imagePath) async {
    final ocrEngine = createOcrEngine();
    String? temporaryImagePath;
    try {
      final sourceBytes = await workspace.readSource(imagePath);
      if (sourceBytes.isEmpty) {
        throw const FormatException('Görsel dosyası boş.');
      }

      final originalCandidate = await ocrEngine.recognize(imagePath);
      var selectedCandidate = originalCandidate;

      try {
        final enhancedBytes = await enhanceImage(sourceBytes);
        if (enhancedBytes.isEmpty) {
          throw const FormatException('İyileştirilmiş görsel boş.');
        }
        temporaryImagePath = await workspace.writeTemporaryImage(enhancedBytes);
        final enhancedCandidate = await ocrEngine.recognize(temporaryImagePath);
        if (enhancedCandidate.score + 0.02 >= originalCandidate.score) {
          selectedCandidate = enhancedCandidate;
        }
      } catch (_) {
        // Original OCR remains usable when enhancement or its OCR pass fails.
      }

      return kDebugMode
          ? normalizeAndLogReceiptText(
              selectedCandidate.text,
              logger: debugPrint,
            )
          : normalizeReceiptText(selectedCandidate.text);
    } finally {
      if (temporaryImagePath != null) {
        try {
          await workspace.deleteTemporaryImage(temporaryImagePath);
        } catch (_) {
          // Cleanup must never hide a successful OCR result or its real error.
        }
      }
      try {
        await ocrEngine.close();
      } catch (_) {
        // Releasing ML Kit resources must not replace the recognition result.
      }
    }
  }
}

class FileSystemReceiptImageWorkspace implements ReceiptImageWorkspace {
  @override
  Future<Uint8List> readSource(String imagePath) =>
      File(imagePath).readAsBytes();

  @override
  Future<String> writeTemporaryImage(Uint8List bytes) async {
    final directory = await Directory.systemTemp.createTemp('receipt_ocr_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}enhanced_receipt.jpg',
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      try {
        await directory.delete(recursive: true);
      } catch (_) {
        // Preserve the original write failure.
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteTemporaryImage(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) await file.delete();
    final directory = file.parent;
    if (await directory.exists()) await directory.delete();
  }
}

class MlKitReceiptOcrEngine implements ReceiptOcrEngine {
  MlKitReceiptOcrEngine()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<ReceiptOcrCandidate> recognize(String imagePath) async {
    final recognizedText = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return _buildOcrCandidate(recognizedText);
  }

  @override
  Future<void> close() => _recognizer.close();
}

/// Extracts and normalizes receipt text from an image already on the device.
Future<String> recognizeReceiptImage(
  String imagePath, {
  ReceiptImageRecognizer? recognizer,
}) =>
    (recognizer ?? OnDeviceReceiptImageRecognizer.mlKit()).recognize(imagePath);

Future<Uint8List> _enhanceInBackground(Uint8List bytes) =>
    compute(enhanceReceiptImage, bytes);

ReceiptOcrCandidate _buildOcrCandidate(RecognizedText recognizedText) {
  final positionedLines = recognizedText.blocks
      .expand((block) => block.lines)
      .map(
        (line) => ReceiptOcrLine(
          text: line.text,
          left: line.boundingBox.left,
          top: line.boundingBox.top,
          right: line.boundingBox.right,
          bottom: line.boundingBox.bottom,
          confidence: line.confidence,
        ),
      )
      .toList();
  final arrangedText = positionedLines.isEmpty
      ? recognizedText.text
      : arrangeReceiptOcrLines(positionedLines);
  final confidences = positionedLines
      .map((line) => line.confidence)
      .whereType<double>()
      .toList();
  final averageConfidence = confidences.isEmpty
      ? null
      : confidences.reduce((a, b) => a + b) / confidences.length;

  return ReceiptOcrCandidate(
    text: arrangedText,
    score: receiptOcrQualityScore(
      arrangedText,
      lineConfidence: averageConfidence,
    ),
  );
}
