import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

void main() {
  test(
    'recognizeReceiptImage delegates through the injectable interface',
    () async {
      final recognizer = _FakeReceiptImageRecognizer('  TOPLAM   10,00 TL  ');

      final result = await recognizeReceiptImage(
        'receipt.jpg',
        recognizer: recognizer,
      );

      expect(result, '  TOPLAM   10,00 TL  ');
      expect(recognizer.receivedPath, 'receipt.jpg');
    },
  );

  group('OnDeviceReceiptImageRecognizer', () {
    test('rejects an empty image before invoking ML Kit', () async {
      final engine = _FakeOcrEngine([]);
      final recognizer = _recognizer(
        engine: engine,
        workspace: _FakeWorkspace(sourceBytes: Uint8List(0)),
      );

      await expectLater(
        recognizer.recognize('empty.jpg'),
        throwsA(
          isA<ReceiptImageValidationException>().having(
            (error) => error.failure,
            'failure',
            ReceiptImageValidationFailure.empty,
          ),
        ),
      );
      expect(engine.recognizeCallCount, 0);
      expect(engine.closeCallCount, 0);
    });

    test('preserves a broken image read error', () async {
      final readError = FileSystemException('Görsel okunamadı');
      final engine = _FakeOcrEngine([]);
      final recognizer = _recognizer(
        engine: engine,
        workspace: _FakeWorkspace(readError: readError),
      );

      await expectLater(recognizer.recognize('broken.jpg'), throwsA(readError));
      expect(engine.recognizeCallCount, 0);
      expect(engine.closeCallCount, 0);
    });

    test('preserves the original ML Kit failure', () async {
      final mlKitError = StateError('ML Kit failed');
      final engine = _FakeOcrEngine([
        mlKitError,
      ], closeError: StateError('close'));
      final recognizer = _recognizer(
        engine: engine,
        workspace: _FakeWorkspace(sourceBytes: _validJpegBytes()),
      );

      await expectLater(
        recognizer.recognize('receipt.jpg'),
        throwsA(same(mlKitError)),
      );
      expect(engine.closeCallCount, 1);
    });

    test('returns original OCR when image enhancement fails', () async {
      final engine = _FakeOcrEngine([
        const ReceiptOcrCandidate(text: '  MARKET\n TOPLAM 10,00 ', score: 0.8),
      ]);
      final recognizer = OnDeviceReceiptImageRecognizer(
        createOcrEngine: () => engine,
        workspace: _FakeWorkspace(sourceBytes: _validJpegBytes()),
        enhanceImage: (_) async => throw StateError('enhancement failed'),
      );

      expect(await recognizer.recognize('corrupt.jpg'), 'MARKET\nTOPLAM 10,00');
      expect(engine.recognizeCallCount, 1);
      expect(engine.closeCallCount, 1);
    });

    test(
      'cleanup failure does not mask a successful enhanced OCR result',
      () async {
        final engine = _FakeOcrEngine([
          const ReceiptOcrCandidate(text: 'ORIGINAL', score: 0.2),
          const ReceiptOcrCandidate(text: '  ENHANCED   RESULT ', score: 0.9),
        ]);
        final workspace = _FakeWorkspace(
          sourceBytes: _validJpegBytes(),
          deleteError: FileSystemException('cleanup failed'),
        );
        final recognizer = _recognizer(engine: engine, workspace: workspace);

        expect(await recognizer.recognize('receipt.jpg'), 'ENHANCED RESULT');
        expect(workspace.deleteCallCount, 1);
        expect(engine.closeCallCount, 1);
      },
    );

    test(
      'creates and closes a fresh OCR engine for every recognition',
      () async {
        final engines = <_FakeOcrEngine>[
          _FakeOcrEngine([
            const ReceiptOcrCandidate(text: 'FIRST', score: 0.8),
          ]),
          _FakeOcrEngine([
            const ReceiptOcrCandidate(text: 'SECOND', score: 0.8),
          ]),
        ];
        var engineIndex = 0;
        final recognizer = OnDeviceReceiptImageRecognizer(
          createOcrEngine: () => engines[engineIndex++],
          workspace: _FakeWorkspace(sourceBytes: _validJpegBytes()),
          enhanceImage: (_) async => throw StateError('enhancement failed'),
        );

        expect(await recognizer.recognize('first.jpg'), 'FIRST');
        expect(await recognizer.recognize('second.jpg'), 'SECOND');
        expect(engineIndex, 2);
        expect(engines.map((engine) => engine.closeCallCount), everyElement(1));
      },
    );

    test(
      'rejects a large image before reading bytes or invoking ML Kit',
      () async {
        final engine = _FakeOcrEngine([]);
        final workspace = _FakeWorkspace(
          sourceBytes: _validJpegBytes(),
          sourceByteLength: maxReceiptImageBytes + 1,
        );
        final recognizer = _recognizer(engine: engine, workspace: workspace);

        await expectLater(
          recognizer.recognize('large.jpg'),
          throwsA(
            isA<ReceiptImageValidationException>().having(
              (error) => error.failure,
              'failure',
              ReceiptImageValidationFailure.tooLarge,
            ),
          ),
        );
        expect(workspace.readCallCount, 0);
        expect(workspace.writeCallCount, 0);
        expect(engine.recognizeCallCount, 0);
        expect(engine.closeCallCount, 0);
      },
    );

    test('rejects corrupt jpg bytes before invoking ML Kit', () async {
      final engine = _FakeOcrEngine([]);
      final workspace = _FakeWorkspace(
        sourceBytes: Uint8List.fromList('not an image'.codeUnits),
      );
      final recognizer = _recognizer(engine: engine, workspace: workspace);

      await expectLater(
        recognizer.recognize('corrupt.jpg'),
        throwsA(
          isA<ReceiptImageValidationException>().having(
            (error) => error.failure,
            'failure',
            ReceiptImageValidationFailure.corrupt,
          ),
        ),
      );
      expect(engine.recognizeCallCount, 0);
      expect(workspace.writeCallCount, 0);
    });

    test('rejects unsupported extensions before reading bytes', () async {
      final engine = _FakeOcrEngine([]);
      final workspace = _FakeWorkspace(sourceBytes: _validJpegBytes());
      final recognizer = _recognizer(engine: engine, workspace: workspace);

      await expectLater(
        recognizer.recognize('receipt.webp'),
        throwsA(
          isA<ReceiptImageValidationException>().having(
            (error) => error.failure,
            'failure',
            ReceiptImageValidationFailure.unsupportedFormat,
          ),
        ),
      );
      expect(workspace.readCallCount, 0);
      expect(engine.recognizeCallCount, 0);
    });

    test('rejects images above the decoded pixel limit', () {
      expect(
        () => validateReceiptImageDimensions(
          width: maxReceiptImagePixels + 1,
          height: 1,
        ),
        throwsA(
          isA<ReceiptImageValidationException>().having(
            (error) => error.failure,
            'failure',
            ReceiptImageValidationFailure.tooManyPixels,
          ),
        ),
      );
    });

    test(
      'rejects oversized decoded dimensions before invoking ML Kit',
      () async {
        final engine = _FakeOcrEngine([]);
        final workspace = _FakeWorkspace(
          sourceBytes: _pngWithDimensions(width: 5001, height: 5000),
        );
        final recognizer = _recognizer(engine: engine, workspace: workspace);

        await expectLater(
          recognizer.recognize('oversized.png'),
          throwsA(
            isA<ReceiptImageValidationException>().having(
              (error) => error.failure,
              'failure',
              ReceiptImageValidationFailure.tooManyPixels,
            ),
          ),
        );
        expect(engine.recognizeCallCount, 0);
      },
    );

    test('removes temporary image when enhanced OCR fails', () async {
      final engine = _FakeOcrEngine([
        const ReceiptOcrCandidate(text: 'ORIGINAL', score: 0.8),
        StateError('enhanced OCR failed'),
      ]);
      final workspace = _FakeWorkspace(sourceBytes: _validJpegBytes());
      final recognizer = _recognizer(engine: engine, workspace: workspace);

      expect(await recognizer.recognize('receipt.jpg'), 'ORIGINAL');
      expect(workspace.writeCallCount, 1);
      expect(workspace.deleteCallCount, 1);
      expect(engine.closeCallCount, 1);
    });
  });

  test('temporary enhanced images use unique system temp locations', () async {
    final workspace = FileSystemReceiptImageWorkspace();
    final sourceDirectory = await Directory.systemTemp.createTemp('source_');
    addTearDown(() async {
      if (await sourceDirectory.exists()) {
        await sourceDirectory.delete(recursive: true);
      }
    });
    final source = File(
      '${sourceDirectory.path}${Platform.pathSeparator}receipt.jpg',
    );
    await source.writeAsBytes([1]);

    final first = await workspace.writeTemporaryImage(Uint8List.fromList([1]));
    final second = await workspace.writeTemporaryImage(Uint8List.fromList([2]));
    addTearDown(() => workspace.deleteTemporaryImage(first));
    addTearDown(() => workspace.deleteTemporaryImage(second));

    expect(first, isNot(second));
    expect(File(first).parent.path, isNot(source.parent.path));
    expect(File(second).parent.path, isNot(source.parent.path));
    expect(first, isNot('${source.path}.ocr.jpg'));
    expect(second, isNot('${source.path}.ocr.jpg'));
  });

  test('temporary image cleanup removes its private directory', () async {
    final workspace = FileSystemReceiptImageWorkspace();
    final temporaryImage = await workspace.writeTemporaryImage(
      _validJpegBytes(),
    );
    final temporaryDirectory = File(temporaryImage).parent;

    expect(await File(temporaryImage).exists(), isTrue);
    await workspace.deleteTemporaryImage(temporaryImage);
    expect(await File(temporaryImage).exists(), isFalse);
    expect(await temporaryDirectory.exists(), isFalse);
  });

  test('temporary image cleanup retries a transient failure', () async {
    var deleteAttempts = 0;
    final workspace = FileSystemReceiptImageWorkspace(
      deleteDirectory: (directory) async {
        deleteAttempts++;
        if (deleteAttempts == 1) {
          throw const FileSystemException('temporary lock');
        }
        await directory.delete(recursive: true);
      },
    );
    final temporaryImage = await workspace.writeTemporaryImage(
      _validJpegBytes(),
    );
    final temporaryDirectory = File(temporaryImage).parent;

    await workspace.deleteTemporaryImage(temporaryImage);

    expect(deleteAttempts, 2);
    expect(await temporaryDirectory.exists(), isFalse);
  });

  test('next cleanup removes an orphaned temporary image', () async {
    final failingWorkspace = FileSystemReceiptImageWorkspace(
      deleteDirectory: (_) async {
        throw const FileSystemException('persistent lock');
      },
    );
    final temporaryImage = await failingWorkspace.writeTemporaryImage(
      _validJpegBytes(),
    );
    final activeDirectory = File(temporaryImage).parent;
    final activeName = activeDirectory.path.split(Platform.pathSeparator).last;
    final orphanedDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'receipt_ocr_orphaned_${activeName.substring('receipt_ocr_'.length)}',
    );
    addTearDown(() async {
      if (await activeDirectory.exists()) {
        await activeDirectory.delete(recursive: true);
      }
      if (await orphanedDirectory.exists()) {
        await orphanedDirectory.delete(recursive: true);
      }
    });

    await expectLater(
      failingWorkspace.deleteTemporaryImage(temporaryImage),
      throwsA(isA<FileSystemException>()),
    );
    expect(await activeDirectory.exists(), isFalse);
    expect(await orphanedDirectory.exists(), isTrue);

    await FileSystemReceiptImageWorkspace().cleanupStaleTemporaryImages();

    expect(await orphanedDirectory.exists(), isFalse);
  });
}

OnDeviceReceiptImageRecognizer _recognizer({
  required _FakeOcrEngine engine,
  required _FakeWorkspace workspace,
}) => OnDeviceReceiptImageRecognizer(
  createOcrEngine: () => engine,
  workspace: workspace,
  enhanceImage: (_) async => Uint8List.fromList([9, 8, 7]),
);

class _FakeReceiptImageRecognizer implements ReceiptImageRecognizer {
  _FakeReceiptImageRecognizer(this.result);

  final String result;
  String? receivedPath;

  @override
  Future<String> recognize(String imagePath) async {
    receivedPath = imagePath;
    return result;
  }
}

class _FakeOcrEngine implements ReceiptOcrEngine {
  _FakeOcrEngine(this.results, {this.closeError});

  final List<Object> results;
  final Object? closeError;
  int recognizeCallCount = 0;
  int closeCallCount = 0;

  @override
  Future<ReceiptOcrCandidate> recognize(String imagePath) async {
    final result = results[recognizeCallCount++];
    if (result is! ReceiptOcrCandidate) throw result;
    return result;
  }

  @override
  Future<void> close() async {
    closeCallCount++;
    if (closeError case final Object error) throw error;
  }
}

class _FakeWorkspace implements ReceiptImageWorkspace {
  _FakeWorkspace({
    this.sourceBytes,
    this.sourceByteLength,
    this.readError,
    this.deleteError,
  });

  final Uint8List? sourceBytes;
  final int? sourceByteLength;
  final Object? readError;
  final Object? deleteError;
  int readCallCount = 0;
  int writeCallCount = 0;
  int deleteCallCount = 0;

  @override
  Future<void> cleanupStaleTemporaryImages() async {}

  @override
  Future<int> sourceLength(String imagePath) async {
    return sourceByteLength ?? sourceBytes?.length ?? _validJpegBytes().length;
  }

  @override
  Future<Uint8List> readSource(String imagePath) async {
    readCallCount++;
    if (readError case final Object error) throw error;
    return sourceBytes ?? _validJpegBytes();
  }

  @override
  Future<String> writeTemporaryImage(Uint8List bytes) async {
    writeCallCount++;
    return '${Directory.systemTemp.path}${Platform.pathSeparator}enhanced.jpg';
  }

  @override
  Future<void> deleteTemporaryImage(String imagePath) async {
    deleteCallCount++;
    if (deleteError case final Object error) throw error;
  }
}

Uint8List _validJpegBytes() {
  final image = image_lib.Image(width: 2, height: 2);
  return Uint8List.fromList(image_lib.encodeJpg(image));
}

Uint8List _pngWithDimensions({required int width, required int height}) {
  final image = image_lib.Image(width: 1, height: 1);
  final bytes = Uint8List.fromList(image_lib.encodePng(image));
  final header = ByteData.sublistView(bytes);
  header.setUint32(16, width, Endian.big);
  header.setUint32(20, height, Endian.big);
  header.setUint32(29, _crc32(bytes.sublist(12, 29)), Endian.big);
  return bytes;
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
