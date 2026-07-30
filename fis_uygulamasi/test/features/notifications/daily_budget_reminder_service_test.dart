import 'package:app_main/features/notifications/daily_budget_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  });
  test(
    'planlanan payload bildirim tıklamasında callback ile iletilir',
    () async {
      final plugin = _MockFlutterLocalNotificationsPlugin();
      final receivedPayloads = <String?>[];

      final service = DailyBudgetReminderService(
        plugin: plugin,
        onNotificationTap: receivedPayloads.add,
        loadTimeZoneIdentifier: () async => 'Europe/Istanbul',
      );

      await service.scheduleDailyReminder(const TimeOfDay(hour: 20, minute: 0));

      expect(
        plugin.scheduledPayload,
        DailyBudgetReminderService.expenseReceiptPayload,
      );

      plugin.simulateTap(plugin.scheduledPayload);

      expect(receivedPayloads, [
        DailyBudgetReminderService.expenseReceiptPayload,
      ]);
      expect(plugin.initializeCallCount, 1);
    },
  );

  test('bildirimden başlatılınca launch payload döndürülür', () async {
    final plugin = _MockFlutterLocalNotificationsPlugin()
      ..launchDetails = const NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: DailyBudgetReminderService.expenseReceiptPayload,
        ),
      );

    final service = DailyBudgetReminderService(
      plugin: plugin,
      loadTimeZoneIdentifier: () async => 'Europe/Istanbul',
    );

    final payload = await service.getLaunchPayload();

    expect(payload, DailyBudgetReminderService.expenseReceiptPayload);
    expect(plugin.initializeCallCount, 1);
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

class _MockFlutterLocalNotificationsPlugin
    implements FlutterLocalNotificationsPlugin {
  DidReceiveNotificationResponseCallback? foregroundCallback;
  NotificationAppLaunchDetails? launchDetails;

  String? scheduledPayload;
  int initializeCallCount = 0;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCallCount += 1;
    foregroundCallback = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduledPayload = payload;
  }

  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return launchDetails;
  }

  void simulateTap(String? payload) {
    foregroundCallback?.call(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload: payload,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
