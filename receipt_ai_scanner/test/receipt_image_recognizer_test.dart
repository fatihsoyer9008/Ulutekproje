import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
        throwsA(isA<FormatException>()),
      );
      expect(engine.recognizeCallCount, 0);
      expect(engine.closeCallCount, 1);
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
      expect(engine.closeCallCount, 1);
    });

    test('preserves the original ML Kit failure', () async {
      final mlKitError = StateError('ML Kit failed');
      final engine = _FakeOcrEngine([
        mlKitError,
      ], closeError: StateError('close'));
      final recognizer = _recognizer(
        engine: engine,
        workspace: _FakeWorkspace(sourceBytes: Uint8List.fromList([1, 2, 3])),
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
        workspace: _FakeWorkspace(sourceBytes: Uint8List.fromList([1, 2, 3])),
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
          sourceBytes: Uint8List.fromList([1, 2, 3]),
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
          workspace: _FakeWorkspace(sourceBytes: Uint8List.fromList([1, 2, 3])),
          enhanceImage: (_) async => throw StateError('enhancement failed'),
        );

        expect(await recognizer.recognize('first.jpg'), 'FIRST');
        expect(await recognizer.recognize('second.jpg'), 'SECOND');
        expect(engineIndex, 2);
        expect(engines.map((engine) => engine.closeCallCount), everyElement(1));
      },
    );
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
  _FakeWorkspace({this.sourceBytes, this.readError, this.deleteError});

  final Uint8List? sourceBytes;
  final Object? readError;
  final Object? deleteError;
  int deleteCallCount = 0;

  @override
  Future<Uint8List> readSource(String imagePath) async {
    if (readError case final Object error) throw error;
    return sourceBytes ?? Uint8List.fromList([1]);
  }

  @override
  Future<String> writeTemporaryImage(Uint8List bytes) async {
    return '${Directory.systemTemp.path}${Platform.pathSeparator}enhanced.jpg';
  }

  @override
  Future<void> deleteTemporaryImage(String imagePath) async {
    deleteCallCount++;
    if (deleteError case final Object error) throw error;
  }
}
