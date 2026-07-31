import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_image_preprocessor.dart';
import 'receipt_ocr_layout.dart';
import 'receipt_text_normalizer.dart';

/// Extracts and normalizes receipt text from an image already on the device.
Future<String> recognizeReceiptImage(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final enhancedPath = '$imagePath.ocr.jpg';
  final enhancedFile = File(enhancedPath);

  try {
    final enhancedBytesFuture = File(imagePath)
        .readAsBytes()
        .then((bytes) => compute(enhanceReceiptImage, bytes));
    final originalResult = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    final originalCandidate = _buildOcrCandidate(originalResult);
    var selectedText = originalCandidate.text;

    try {
      final enhancedBytes = await enhancedBytesFuture;
      await enhancedFile.writeAsBytes(enhancedBytes, flush: true);
      final enhancedResult = await recognizer.processImage(
        InputImage.fromFilePath(enhancedPath),
      );
      final enhancedCandidate = _buildOcrCandidate(enhancedResult);
      if (enhancedCandidate.score + 0.02 >= originalCandidate.score) {
        selectedText = enhancedCandidate.text;
      }
    } on Exception {
      // The original OCR result is still usable when enhancement fails.
    }

    return kDebugMode
        ? normalizeAndLogReceiptText(selectedText, logger: debugPrint)
        : normalizeReceiptText(selectedText);
  } finally {
    if (await enhancedFile.exists()) await enhancedFile.delete();
    await recognizer.close();
  }
}

_ReceiptOcrCandidate _buildOcrCandidate(RecognizedText recognizedText) {
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

  return _ReceiptOcrCandidate(
    text: arrangedText,
    score: receiptOcrQualityScore(
      arrangedText,
      lineConfidence: averageConfidence,
    ),
  );
}

class _ReceiptOcrCandidate {
  const _ReceiptOcrCandidate({required this.text, required this.score});

  final String text;
  final double score;
}
