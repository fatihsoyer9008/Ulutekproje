import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  static const _enabledKey = 'daily_reminder_enabled';
  static const _hourKey = 'daily_reminder_hour';
  static const _minuteKey = 'daily_reminder_minute';

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<TimeOfDay> getReminderTime() async {
    final preferences = await SharedPreferences.getInstance();

    return TimeOfDay(
      hour: preferences.getInt(_hourKey) ?? 20,
      minute: preferences.getInt(_minuteKey) ?? 0,
    );
  }

  Future<void> saveEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);
  }

  Future<void> saveReminderTime(TimeOfDay time) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setInt(_hourKey, time.hour);
    await preferences.setInt(_minuteKey, time.minute);
  }
}
