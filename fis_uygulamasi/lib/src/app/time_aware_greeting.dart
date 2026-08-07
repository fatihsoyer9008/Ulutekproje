import 'dart:math';

enum GreetingPeriod { morning, noon, evening, night }

abstract final class TimeAwareGreeting {
  static const _morningMessages = <String>[
    '{name}, günaydın!',
    '{name}, güzel bir sabah!',
    '{name}, mutlu sabahlar!',
  ];

  static const _noonMessages = <String>[
    '{name}, iyi günler!',
    '{name}, keyifli günler!',
    '{name}, güzel bir gün!',
  ];

  static const _eveningMessages = <String>[
    '{name}, iyi akşamlar!',
    '{name}, günün nasıldı?',
    '{name}, keyifli akşamlar!',
  ];

  static const _nightMessages = <String>[
    '{name}, iyi geceler!',
    '{name}, günün özeti?',
    '{name}, huzurlu geceler!',
  ];

  static GreetingPeriod periodFor(DateTime localTime) {
    final hour = localTime.hour;
    if (hour >= 5 && hour < 11) return GreetingPeriod.morning;
    if (hour >= 11 && hour < 17) return GreetingPeriod.noon;
    if (hour >= 17 && hour < 24) return GreetingPeriod.evening;
    return GreetingPeriod.night;
  }

  static String compose({
    required String name,
    required DateTime localTime,
    Random? random,
    int? variantIndex,
  }) {
    final messages = switch (periodFor(localTime)) {
      GreetingPeriod.morning => _morningMessages,
      GreetingPeriod.noon => _noonMessages,
      GreetingPeriod.evening => _eveningMessages,
      GreetingPeriod.night => _nightMessages,
    };
    final index = variantIndex ?? (random ?? Random()).nextInt(messages.length);
    return messages[index.abs() % messages.length].replaceFirst('{name}', name);
  }
}
