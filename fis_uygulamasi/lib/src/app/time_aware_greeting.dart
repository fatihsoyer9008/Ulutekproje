import 'dart:math';

enum GreetingPeriod { morning, noon, evening, night }

abstract final class TimeAwareGreeting {
  static const _morningMessages = <String>[
    'Günaydın, {name}',
    'Güne güzel başlayalım, {name}',
    'Harika bir sabah olsun, {name}',
  ];

  static const _noonMessages = <String>[
    'İyi öğlenler, {name}',
    'Günün güzel geçsin, {name}',
    'Keyifli bir öğlen olsun, {name}',
  ];

  static const _eveningMessages = <String>[
    'İyi akşamlar, {name}',
    'Günün nasıl geçti, {name}?',
    'Keyifli akşamlar, {name}',
  ];

  static const _nightMessages = <String>[
    'İyi geceler, {name}',
    'Geceye kısa bir finans özeti, {name}?',
    'Huzurlu geceler, {name}',
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
