import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai_scanner/src/captured_receipt_photo.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'captured_receipt_test_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('deletes the original camera photo after successful OCR', () async {
    final photoFile = File('${temporaryDirectory.path}/capture.jpg');
    await photoFile.writeAsBytes([1, 2, 3]);

    final result = await recognizeAndDeleteCapturedReceiptPhoto(
      XFile(photoFile.path),
      recognize: (imagePath) async {
        expect(imagePath, photoFile.path);
        expect(await photoFile.exists(), isTrue);
        return 'MIGROS TOPLAM 25,50 TL';
      },
    );

    expect(result, 'MIGROS TOPLAM 25,50 TL');
    expect(await photoFile.exists(), isFalse);
  });

  test('deletes the original camera photo when OCR fails', () async {
    final photoFile = File('${temporaryDirectory.path}/capture.jpg');
    await photoFile.writeAsBytes([1, 2, 3]);

    await expectLater(
      recognizeAndDeleteCapturedReceiptPhoto(
        XFile(photoFile.path),
        recognize: (_) async => throw StateError('OCR failed'),
      ),
      throwsStateError,
    );

    expect(await photoFile.exists(), isFalse);
  });

  test('cleanup failure does not mask a successful OCR result', () async {
    var deleteCalled = false;

    final result = await recognizeAndDeleteCapturedReceiptPhoto(
      XFile('${temporaryDirectory.path}/capture.jpg'),
      recognize: (_) async => 'OCR result',
      deleteFile: (_) async {
        deleteCalled = true;
        throw const FileSystemException('cleanup failed');
      },
    );

    expect(result, 'OCR result');
    expect(deleteCalled, isTrue);
  });
}
