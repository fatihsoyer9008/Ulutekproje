import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_image_preprocessor.dart';
import 'receipt_image_validator.dart';
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
  Future<void> cleanupStaleTemporaryImages();

  Future<int> sourceLength(String imagePath);

  Future<Uint8List> readSource(String imagePath);

  Future<String> writeTemporaryImage(Uint8List bytes);

  Future<void> deleteTemporaryImage(String imagePath);
}

typedef ReceiptImageEnhancer = Future<Uint8List> Function(Uint8List bytes);
typedef ReceiptOcrEngineFactory = ReceiptOcrEngine Function();
typedef ReceiptTemporaryDirectoryDeleter =
    Future<void> Function(Directory directory);

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
    ReceiptOcrEngine? ocrEngine;
    String? temporaryImagePath;
    try {
      await workspace.cleanupStaleTemporaryImages();
      final sourceLength = await workspace.sourceLength(imagePath);
      validateReceiptImageSelection(
        imagePath: imagePath,
        byteLength: sourceLength,
      );
      final sourceBytes = await workspace.readSource(imagePath);
      await validateReceiptImageBytes(imagePath: imagePath, bytes: sourceBytes);

      final engine = createOcrEngine();
      ocrEngine = engine;
      final originalCandidate = await engine.recognize(imagePath);
      var selectedCandidate = originalCandidate;

      try {
        final enhancedBytes = await enhanceImage(sourceBytes);
        if (enhancedBytes.isEmpty) {
          throw const FormatException('İyileştirilmiş görsel boş.');
        }
        temporaryImagePath = await workspace.writeTemporaryImage(enhancedBytes);
        final enhancedCandidate = await engine.recognize(temporaryImagePath);
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
        } on Exception catch (error, stackTrace) {
          debugPrint('[ReceiptScanner] Geçici görsel temizlenemedi: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      try {
        await ocrEngine?.close();
      } catch (_) {
        // Releasing ML Kit resources must not replace the recognition result.
      }
    }
  }
}

class FileSystemReceiptImageWorkspace implements ReceiptImageWorkspace {
  FileSystemReceiptImageWorkspace({
    ReceiptTemporaryDirectoryDeleter? deleteDirectory,
  }) : _deleteDirectory = deleteDirectory ?? _deleteDirectoryRecursively;

  static const _temporaryDirectoryPrefix = 'receipt_ocr_';
  static const _orphanedDirectoryPrefix = 'receipt_ocr_orphaned_';
  static const _staleDirectoryAge = Duration(days: 1);

  final ReceiptTemporaryDirectoryDeleter _deleteDirectory;

  @override
  Future<void> cleanupStaleTemporaryImages() async {
    final now = DateTime.now();
    try {
      await for (final entity in Directory.systemTemp.list(
        followLinks: false,
      )) {
        if (entity is! Directory) continue;
        final name = _fileName(entity.path);
        final isOrphaned = name.startsWith(_orphanedDirectoryPrefix);
        final isOldTemporaryDirectory =
            !isOrphaned &&
            name.startsWith(_temporaryDirectoryPrefix) &&
            now.difference((await entity.stat()).modified) >=
                _staleDirectoryAge;
        if (!isOrphaned && !isOldTemporaryDirectory) continue;

        try {
          await entity.delete(recursive: true);
        } on FileSystemException catch (error, stackTrace) {
          debugPrint(
            '[ReceiptScanner] Eski geçici görsel temizlenemedi: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } on FileSystemException catch (error, stackTrace) {
      debugPrint('[ReceiptScanner] Geçici klasörler taranamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<int> sourceLength(String imagePath) => File(imagePath).length();

  @override
  Future<Uint8List> readSource(String imagePath) =>
      File(imagePath).readAsBytes();

  @override
  Future<String> writeTemporaryImage(Uint8List bytes) async {
    final directory = await Directory.systemTemp.createTemp(
      _temporaryDirectoryPrefix,
    );
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
    final directory = File(imagePath).parent;
    if (!await directory.exists()) return;
    if (!_fileName(directory.path).startsWith(_temporaryDirectoryPrefix)) {
      final file = File(imagePath);
      if (await file.exists()) await file.delete();
      return;
    }

    FileSystemException? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _deleteDirectory(directory);
        return;
      } on FileSystemException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    await _markForLaterCleanup(directory);
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<void> _markForLaterCleanup(Directory directory) async {
    final name = _fileName(directory.path);
    final suffix = name.substring(_temporaryDirectoryPrefix.length);
    final orphanedDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      '$_orphanedDirectoryPrefix$suffix',
    );
    try {
      await directory.rename(orphanedDirectory.path);
    } on FileSystemException catch (error, stackTrace) {
      debugPrint(
        '[ReceiptScanner] Geçici görsel sonraki temizliğe işaretlenemedi: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _deleteDirectoryRecursively(Directory directory) =>
      directory.delete(recursive: true);

  static String _fileName(String path) =>
      path.split(Platform.pathSeparator).where((part) => part.isNotEmpty).last;
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
