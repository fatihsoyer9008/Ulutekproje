import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

void main() {
  testWidgets('scanner screen can be constructed', (tester) async {
    const screen = ReceiptScannerScreen();
    expect(screen, isA<ReceiptScannerScreen>());
  });

  group('camera permission failures', () {
    test('allows retry when permission can be requested again', () {
      final failure = cameraFailureFromException(
        CameraException('CameraAccessDenied', 'denied'),
      );

      expect(failure.type, CameraFailureType.permissionDenied);
      expect(failure.title, 'Kamera izni gerekli');
      expect(failure.canRetry, isTrue);
    });

    test('directs permanently denied permission to device settings', () {
      final failure = cameraFailureFromException(
        CameraException('CameraAccessDeniedWithoutPrompt', 'blocked'),
      );

      expect(failure.type, CameraFailureType.permissionBlocked);
      expect(failure.message, contains('Cihaz ayarlarından'));
      expect(failure.canRetry, isFalse);
    });

    test('explains system-restricted camera access', () {
      final failure = cameraFailureFromException(
        CameraException('CameraAccessRestricted', 'restricted'),
      );

      expect(failure.type, CameraFailureType.restricted);
      expect(failure.message, contains('kısıtlanmış'));
      expect(failure.canRetry, isFalse);
    });
  });

  group('receipt text normalization', () {
    test('removes redundant whitespace and keeps meaningful lines', () {
      const rawText =
          '  MARKET   A.Ş. \r\n'
          '\tTarih:\t 26.07.2026  \r\n'
          '   \r\n'
          '  TOPLAM    125,50 TL  ';

      expect(
        normalizeReceiptText(rawText),
        'MARKET A.Ş.\nTarih: 26.07.2026\nTOPLAM 125,50 TL',
      );
    });

    test('logs normalized text to the debug console', () {
      final logs = <String>[];

      final result = normalizeAndLogReceiptText(
        '  ÜRÜN    1 \n\n TOPLAM\t 10,00 TL ',
        logger: logs.add,
      );

      expect(result, 'ÜRÜN 1\nTOPLAM 10,00 TL');
      expect(logs, hasLength(1));
      expect(logs.single, contains(result));
    });

    test('returns empty text for whitespace-only OCR output', () {
      expect(normalizeReceiptText(' \t\r\n  \n'), isEmpty);
    });
  });
}
