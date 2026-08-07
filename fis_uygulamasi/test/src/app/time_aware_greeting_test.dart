import 'package:app_main/src/app/time_aware_greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeAwareGreeting', () {
    test('uses the phone local hour to select the greeting period', () {
      expect(
        TimeAwareGreeting.periodFor(DateTime(2026, 8, 5, 8)),
        GreetingPeriod.morning,
      );
      expect(
        TimeAwareGreeting.periodFor(DateTime(2026, 8, 5, 13)),
        GreetingPeriod.noon,
      );
      expect(
        TimeAwareGreeting.periodFor(DateTime(2026, 8, 5, 20)),
        GreetingPeriod.evening,
      );
      expect(
        TimeAwareGreeting.periodFor(DateTime(2026, 8, 5, 2)),
        GreetingPeriod.night,
      );
    });

    test('offers multiple variants for every period', () {
      final hours = [8, 13, 20, 2];

      for (final hour in hours) {
        final variants = {
          for (var index = 0; index < 3; index++)
            TimeAwareGreeting.compose(
              name: 'Alihan',
              localTime: DateTime(2026, 8, 5, hour),
              variantIndex: index,
            ),
        };

        expect(variants, hasLength(3));
        expect(variants.every((message) => message.contains('Alihan')), isTrue);
      }
    });

    test('uses expected primary greeting for each period', () {
      expect(_greetingAt(8), 'Alihan, günaydın!');
      expect(_greetingAt(13), 'Alihan, iyi günler!');
      expect(_greetingAt(20), 'Alihan, iyi akşamlar!');
      expect(_greetingAt(2), 'Alihan, iyi geceler!');
    });
  });
}

String _greetingAt(int hour) => TimeAwareGreeting.compose(
  name: 'Alihan',
  localTime: DateTime(2026, 8, 5, hour),
  variantIndex: 0,
);
