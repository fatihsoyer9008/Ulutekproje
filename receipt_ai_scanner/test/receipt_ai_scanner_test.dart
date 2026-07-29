import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
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

  group('receipt OCR layout', () {
    test('orders visual rows and joins right-aligned amounts', () {
      const lines = [
        ReceiptOcrLine(
          text: '*79.00',
          left: 310,
          top: 105,
          right: 390,
          bottom: 125,
        ),
        ReceiptOcrLine(
          text: 'TOPLAM',
          left: 20,
          top: 160,
          right: 120,
          bottom: 180,
        ),
        ReceiptOcrLine(
          text: 'YUMURTA 30LU M %1.0',
          left: 20,
          top: 100,
          right: 250,
          bottom: 122,
        ),
        ReceiptOcrLine(
          text: '*79.25',
          left: 310,
          top: 161,
          right: 390,
          bottom: 181,
        ),
        ReceiptOcrLine(
          text: 'Tarih: 01/05/2024 Saat: 20:37',
          left: 20,
          top: 45,
          right: 350,
          bottom: 65,
        ),
      ];

      expect(
        arrangeReceiptOcrLines(lines),
        'Tarih: 01/05/2024 Saat: 20:37\n'
        'YUMURTA 30LU M %1.0 *79.00\n'
        'TOPLAM *79.25',
      );
    });

    test('scores useful receipt text above noisy OCR', () {
      const useful =
          'A101 YENİ MAĞAZACILIK A.Ş.\n'
          'Tarih: 01/05/2024\n'
          'YUMURTA 30LU *79.00\n'
          'TOPLAM *79.25';

      expect(
        receiptOcrQualityScore(useful),
        greaterThan(receiptOcrQualityScore('Je nc\n-- ? 1181YK03')),
      );
    });
  });

  test('receipt image enhancement expands thermal print contrast', () {
    final source = image_lib.Image(width: 80, height: 80);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final tone = y >= 30 && y < 40 ? 155 : 190;
        source.setPixelRgb(x, y, tone, tone, tone);
      }
    }

    final enhancedBytes = enhanceReceiptImage(image_lib.encodePng(source));
    final enhanced = image_lib.decodeImage(enhancedBytes);

    expect(enhanced, isNotNull);
    final background = enhanced!.getPixel(10, 10).luminance;
    final print = enhanced.getPixel(10, 35).luminance;
    expect((background - print).abs(), greaterThan(35));
  });
}
