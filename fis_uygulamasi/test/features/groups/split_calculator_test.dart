import 'package:app_main/features/groups/domain/split_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kuruş tabanlı bölüştürme', () {
    test('eşit bölmede kalan kuruşları deterministik dağıtır', () {
      expect(splitEqualInMinor(100, 3), [34, 33, 33]);
      expect(splitEqualInMinor(100, 3), [34, 33, 33]);
      expect(splitEqualInMinor(2, 3), [1, 1, 0]);
    });

    test('yüzdelik bölmede toplamı eksiksiz korur', () {
      final result = splitByBasisPointsInMinor(101, [3333, 3333, 3334]);
      expect(result.fold<int>(0, (a, b) => a + b), 101);
      expect(result, [34, 34, 33]);
    });

    test('toplamı 10000 olmayan yüzdeleri reddeder', () {
      expect(
        () => splitByBasisPointsInMinor(100, [5000, 4999]),
        throwsArgumentError,
      );
    });
  });
}
