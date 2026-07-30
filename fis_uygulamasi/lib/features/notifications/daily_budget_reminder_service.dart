import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

typedef NotificationTapHandler = void Function(String? payload);
typedef TimeZoneIdentifierLoader = Future<String> Function();

/// Her gün kullanıcının seçtiği saatte harcama girmeyi hatırlatır.
class DailyBudgetReminderService {
  DailyBudgetReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    this.onNotificationTap,
    TimeZoneIdentifierLoader? loadTimeZoneIdentifier,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _loadTimeZoneIdentifier =
           loadTimeZoneIdentifier ?? _loadDeviceTimeZoneIdentifier;

  static const notificationId = 1001;

  /// Bildirime basıldığında hangi işlemin yapılacağını belirtir.
  static const expenseReceiptPayload = 'expense_receipt';

  static const _channelId = 'daily_budget_reminders';
  static const _channelName = 'Günlük bütçe hatırlatıcıları';
  static const _channelDescription = 'Günlük harcama girişi için hatırlatmalar';

  final FlutterLocalNotificationsPlugin _plugin;
  final TimeZoneIdentifierLoader _loadTimeZoneIdentifier;
  final NotificationTapHandler? onNotificationTap;

  Future<void>? _initialization;

  /// Bildirim eklentisini ve cihaz saat dilimini hazırlar.
  Future<void> initialize() => _initialization ??= _initialize();

  static Future<String> _loadDeviceTimeZoneIdentifier() async {
    final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
    return deviceTimeZone.identifier;
  }

  Future<void> _initialize() async {
    tz.initializeTimeZones();

    final timeZoneIdentifier = await _loadTimeZoneIdentifier();

    tz.setLocalLocation(tz.getLocation(timeZoneIdentifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
  }

  @visibleForTesting
  static tz.TZDateTime nextOccurrence(TimeOfDay time, {tz.TZDateTime? now}) {
    final current = now ?? tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      current.year,
      current.month,
      current.day,
      time.hour,
      time.minute,
    );

    if (!scheduled.isAfter(current)) {
      scheduled = tz.TZDateTime(
        tz.local,
        current.year,
        current.month,
        current.day + 1,
        time.hour,
        time.minute,
      );
    }

    return scheduled;
  }

  /// Android 13 ve sonrasında bildirim izni ister.
  Future<bool> requestPermission() async {
    await initialize();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await androidPlugin?.requestNotificationsPermission() ?? true;
  }

  /// Her gün seçilen saatte hatırlatıcı planlar.
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await initialize();

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Günlük harcamanı eklemeyi unutma!',
      body: 'Bugünkü harcamalarını kaydederek bütçeni güncel tut.',
      payload: expenseReceiptPayload,
      scheduledDate: nextOccurrence(time),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Uygulama tamamen kapalıyken bildirime basılarak
  /// başlatılıp başlatılmadığını kontrol eder.
  Future<String?> getLaunchPayload() async {
    await initialize();

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp != true) {
      return null;
    }

    return launchDetails?.notificationResponse?.payload;
  }

  /// Planlanmış günlük hatırlatıcıyı iptal eder.
  Future<void> cancelDailyReminder() async {
    await initialize();
    await _plugin.cancel(id: notificationId);
  }
}
