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
}
