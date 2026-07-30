import 'package:app_main/features/notifications/daily_budget_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  });

  test('seçilen saat henüz gelmediyse bugünü planlar', () {
    final now = tz.TZDateTime(tz.local, 2026, 7, 29, 9, 0);

    final scheduled = DailyBudgetReminderService.nextOccurrence(
      const TimeOfDay(hour: 20, minute: 0),
      now: now,
    );

    expect(scheduled, tz.TZDateTime(tz.local, 2026, 7, 29, 20));
  });

  test('seçilen saat geçtiyse ertesi günü planlar', () {
    final now = tz.TZDateTime(tz.local, 2026, 7, 29, 20, 0);

    final scheduled = DailyBudgetReminderService.nextOccurrence(
      const TimeOfDay(hour: 20, minute: 0),
      now: now,
    );

    expect(scheduled, tz.TZDateTime(tz.local, 2026, 7, 30, 20));
  });
  test('seçilen saatten bir dakika önceyse bugünü planlar', () {
    final now = tz.TZDateTime(tz.local, 2026, 7, 29, 19, 59);

    final scheduled = DailyBudgetReminderService.nextOccurrence(
      const TimeOfDay(hour: 20, minute: 0),
      now: now,
    );

    expect(scheduled, tz.TZDateTime(tz.local, 2026, 7, 29, 20));
  });

  test('seçilen saat bir dakika geçmişse ertesi günü planlar', () {
    final now = tz.TZDateTime(tz.local, 2026, 7, 29, 20, 1);

    final scheduled = DailyBudgetReminderService.nextOccurrence(
      const TimeOfDay(hour: 20, minute: 0),
      now: now,
    );

    expect(scheduled, tz.TZDateTime(tz.local, 2026, 7, 30, 20));
  });

  test('ayın son gününde sonraki ayı doğru planlar', () {
    final now = tz.TZDateTime(tz.local, 2026, 7, 31, 21);

    final scheduled = DailyBudgetReminderService.nextOccurrence(
      const TimeOfDay(hour: 20, minute: 0),
      now: now,
    );

    expect(scheduled, tz.TZDateTime(tz.local, 2026, 8, 1, 20));
  });

  test('yılın son gününde sonraki yılı doğru planlar', () {
    final now = tz.TZDateTime(tz.local, 2026, 12, 31, 21);

    final scheduled = DailyBudgetReminderService.nextOccurrence(
      const TimeOfDay(hour: 20, minute: 0),
      now: now,
    );

    expect(scheduled, tz.TZDateTime(tz.local, 2027, 1, 1, 20));
  });
}
