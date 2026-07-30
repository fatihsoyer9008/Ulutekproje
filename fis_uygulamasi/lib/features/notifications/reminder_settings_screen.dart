import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_providers.dart';

import 'daily_budget_reminder_service.dart';
import 'notification_preferences.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState
    extends ConsumerState<ReminderSettingsScreen> {
  DailyBudgetReminderService get _reminderService =>
      ref.read(dailyBudgetReminderServiceProvider);

  final NotificationPreferences _preferences = NotificationPreferences();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _preferences.isEnabled();
    final time = await _preferences.getReminderTime();

    if (!mounted) return;

    setState(() {
      _enabled = enabled;
      _time = time;
      _loading = false;
    });
  }

  Future<void> _changeEnabled(bool enabled) async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      if (enabled) {
        final granted = await _reminderService.requestPermission();

        if (!granted) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bildirim izni verilmedi.')),
          );

          return;
        }

        await _reminderService.scheduleDailyReminder(_time);
        await _preferences.saveEnabled(true);
      } else {
        await _reminderService.cancelDailyReminder();
        await _preferences.saveEnabled(false);
      }

      if (!mounted) return;

      setState(() {
        _enabled = enabled;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hatırlatıcı ayarlanamadı: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _selectTime() async {
    if (_saving) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Hatırlatma saatini seç',
      cancelText: 'İptal',
      confirmText: 'Kaydet',
    );

    if (selectedTime == null) return;

    setState(() {
      _saving = true;
    });

    try {
      await _preferences.saveReminderTime(selectedTime);

      if (_enabled) {
        await _reminderService.scheduleDailyReminder(selectedTime);
      }

      if (!mounted) return;

      setState(() {
        _time = selectedTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hatırlatma saati ${selectedTime.format(context)} olarak ayarlandı.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saat kaydedilemedi: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Harcama hatırlatıcısı')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: const Text('Günlük hatırlatıcı'),
            subtitle: Text(
              _enabled
                  ? 'Her gün ${_time.format(context)} saatinde bildirilecek.'
                  : 'Hatırlatıcı şu anda kapalı.',
            ),
            value: _enabled,
            onChanged: _saving ? null : _changeEnabled,
          ),
          const Divider(),
          ListTile(
            enabled: _enabled && !_saving,
            leading: const Icon(Icons.schedule),
            title: const Text('Hatırlatma saati'),
            subtitle: const Text(
              'Günlük harcama bildiriminin gösterileceği saat',
            ),
            trailing: Text(
              _time.format(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: _enabled && !_saving ? _selectTime : null,
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
