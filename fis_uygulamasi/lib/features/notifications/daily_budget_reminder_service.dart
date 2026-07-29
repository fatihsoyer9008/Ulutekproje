import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Her gün kullanıcının seçtiği saatte harcama girmeyi hatırlatır.
///
/// Bu servis yalnızca bildirimi planlar. Bildirime tıklanınca hangi ekrana
/// gidileceği, yönlendirme (deep link) görevi kapsamında ayrıca ele alınır.
class DailyBudgetReminderService {
  DailyBudgetReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const notificationId = 1001;
  static const _channelId = 'daily_budget_reminders';
  static const _channelName = 'Günlük bütçe hatırlatıcıları';
  static const _channelDescription =
      'Günlük harcama girişi için hatırlatmalar';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;

  /// Platforma ait bildirim izinlerini hazırlar ve cihazın saat dilimini ayarlar.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    tz.initializeTimeZones();
    final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimeZone.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );
    await _plugin.initialize(settings: settings);
  }

  /// Seçilen saate göre bir sonraki güncel zamanı döndürür.
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
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Android 13 ve sonrasında kullanıcıdan bildirim izni ister.
  Future<bool> requestPermission() async {
    await initialize();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    return await androidPlugin?.requestNotificationsPermission() ?? true;
  }

  /// Her gün [time] saatinde gösterilecek bütçe hatırlatıcısını planlar.
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await initialize();
    final granted = await requestPermission();
    if (!granted) {
      throw StateError('Bildirim izni verilmedi.');
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Günlük harcamanı eklemeyi unutma',
      body: 'Bugünkü harcamalarını kaydederek bütçeni güncel tut.',
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

  /// Daha önce planlanan günlük hatırlatıcıyı kaldırır.
  Future<void> cancelDailyReminder() async {
    await initialize();
    await _plugin.cancel(id: notificationId);
  }
}
