import 'package:app_main/features/groups/application/fast_split_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FastSplitCalculator', () {
    test('eşit bölüşümde kuruş kalanını üye sırasına göre dağıtır', () {
      final result = FastSplitCalculator.equal(
        totalAmountInMinor: 100,
        memberIds: const ['a', 'b', 'c'],
      );

      expect(
        result.shares.map((share) => share.amountInMinor),
        orderedEquals([34, 33, 33]),
      );
      expect(result.isBalanced, isTrue);
    });

    test('yüzdelik bölüşümde basis point ve kuruş hesabı kullanır', () {
      final result = FastSplitCalculator.percentage(
        totalAmountInMinor: 10001,
        memberIds: const ['a', 'b'],
        percentageBasisPoints: const {'a': 6000, 'b': 4000},
      );

      expect(
        result.shares.map((share) => share.amountInMinor),
        orderedEquals([6001, 4000]),
      );
      expect(result.isBalanced, isTrue);
    });

    test('yüzdelerin tam olarak yüzde 100 olmasını zorunlu tutar', () {
      expect(
        () => FastSplitCalculator.percentage(
          totalAmountInMinor: 10000,
          memberIds: const ['a', 'b'],
          percentageBasisPoints: const {'a': 5000, 'b': 4999},
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('tutar bazlı bölüşümde kuruş farkını döndürür', () {
      final result = FastSplitCalculator.fixedAmount(
        totalAmountInMinor: 10000,
        memberIds: const ['a', 'b'],
        amountsInMinor: const {'a': 4000, 'b': 5999},
      );

      expect(result.differenceInMinor, 1);
      expect(result.isBalanced, isFalse);
    });

    test('negatif ve aralık dışı domain girdilerini reddeder', () {
      expect(
        () => FastSplitCalculator.fixedAmount(
          totalAmountInMinor: 100,
          memberIds: const ['a'],
          amountsInMinor: const {'a': -1},
        ),
        throwsFormatException,
      );
      expect(
        () => FastSplitCalculator.percentage(
          totalAmountInMinor: 100,
          memberIds: const ['a', 'b'],
          percentageBasisPoints: const {'a': 10001, 'b': -1},
        ),
        throwsFormatException,
      );
    });

    test('boş ve tekrarlanan kullanıcı kimliklerini reddeder', () {
      for (final ids in <List<String>>[
        ['', 'b'],
        ['a', 'a'],
      ]) {
        expect(
          () => FastSplitCalculator.equal(
            totalAmountInMinor: 100,
            memberIds: ids,
          ),
          throwsFormatException,
        );
      }
    });

    test('seçili üyeler dışında verilen payları reddeder', () {
      expect(
        () => FastSplitCalculator.fixedAmount(
          totalAmountInMinor: 100,
          memberIds: const ['a'],
          amountsInMinor: const {'a': 100, 'b': 0},
        ),
        throwsFormatException,
      );
      expect(
        () => FastSplitCalculator.percentage(
          totalAmountInMinor: 100,
          memberIds: const ['a'],
          percentageBasisPoints: const {'a': 10000, 'b': 0},
        ),
        throwsFormatException,
      );
    });
  });
}
