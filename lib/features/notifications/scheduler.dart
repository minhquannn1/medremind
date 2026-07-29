import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../db/repositories/prescriptions_repository.dart';
import '../../db/repositories/settings_repository.dart';
import '../../i18n/app_localizations.dart';

/// Local dose reminders. Ported from `src/features/notifications/scheduler.ts`
/// (expo-notifications → flutter_local_notifications).
///
/// Reminders repeat daily at a wall-clock time, so they are scheduled in the
/// device's timezone rather than UTC: a dose set for 08:00 must stay 08:00 when
/// the user travels.

const String androidChannelId = 'medication-reminders';

class ReminderPrefs {
  final bool sound;
  final bool vibration;

  const ReminderPrefs({required this.sound, required this.vibration});
}

class NotificationScheduler {
  NotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.settings = const SettingsRepository(),
    this.prescriptions = const PrescriptionsRepository(),
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final SettingsRepository settings;
  final PrescriptionsRepository prescriptions;

  bool _timezoneReady = false;

  Future<ReminderPrefs> getReminderPrefs() async => ReminderPrefs(
        sound: await settings.getBool(SettingsKeys.reminderSound, true),
        vibration: await settings.getBool(SettingsKeys.reminderVibration, true),
      );

  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Falling back to UTC would shift every reminder; keep the package
      // default local zone instead of guessing.
    }
    _timezoneReady = true;
  }

  /// Must run before any scheduling. Safe to call more than once.
  Future<void> initialize(Translations t) async {
    await _ensureTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      // Permission is requested explicitly later, in context, so the prompt
      // appears when the user has a reason to say yes.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    await configureAndroidChannel(t);
  }

  Future<void> configureAndroidChannel(Translations t) async {
    if (!Platform.isAndroid) return;
    final prefs = await getReminderPrefs();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        androidChannelId,
        t.t('reminders.channelName'),
        importance: Importance.high,
        playSound: prefs.sound,
        enableVibration: prefs.vibration,
        ledColor: const Color(0xFF0E7C7B),
      ),
    );
  }

  /// Re-applies reminder preferences. Android channels are immutable once
  /// created, so the channel is deleted and recreated, then reminders are
  /// rescheduled so queued notifications pick up the new sound setting.
  Future<void> applyReminderPrefs(int? patientId, Translations t) async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      try {
        await android?.deleteNotificationChannel(androidChannelId);
      } catch (_) {
        // Nothing to delete on a fresh install.
      }
      await configureAndroidChannel(t);
    }
    if (patientId != null) await syncReminders(patientId, t);
  }

  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await ios?.checkPermissions();
      return settings?.isAlertEnabled ?? false;
    }
    return false;
  }

  /// Stable per-(medication, time) id so rescheduling replaces rather than
  /// duplicates. Kept inside 32 bits, which is the platform id limit.
  static int notificationId(int medicationId, int hour, int minute) =>
      ((medicationId * 1440) + (hour * 60) + minute) & 0x7FFFFFFF;

  NotificationDetails _details(ReminderPrefs prefs, String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: prefs.sound,
        enableVibration: prefs.vibration,
      ),
      iOS: DarwinNotificationDetails(presentSound: prefs.sound),
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Cancels every scheduled reminder and reschedules daily ones for each
  /// active medication / schedule time. Call after any prescription change.
  ///
  /// Returns false when notifications are not permitted — the caller decides
  /// whether to warn, because silently doing nothing is how users end up with
  /// medications and no reminders.
  Future<bool> syncReminders(int patientId, Translations t) async {
    if (!await hasPermission()) return false;
    await _ensureTimezone();
    await _plugin.cancelAll();

    final prefs = await getReminderPrefs();
    final details = _details(prefs, t.t('reminders.channelName'));
    final meds = await prescriptions.listActiveMedicationsWithSchedule(patientId);
    final today = DateTime.now();

    for (final entry in meds) {
      final med = entry.medication;

      // Skip medications whose course has already ended.
      if (med.startDate != null && med.durationDays != null) {
        final start = DateTime.tryParse(med.startDate!);
        if (start != null && med.durationDays! > 0) {
          final end = DateTime(start.year, start.month, start.day)
              .add(Duration(days: med.durationDays! - 1))
              .add(const Duration(hours: 23, minutes: 59));
          if (today.isAfter(end)) continue;
        }
      }

      for (final time in entry.times) {
        final parts = time.time.split(':');
        final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '');
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '');
        if (hour == null || minute == null) continue;

        await _plugin.zonedSchedule(
          notificationId(med.id, hour, minute),
          t.t('reminders.doseTitle'),
          t.t('reminders.doseBody', params: {
            'medication': med.name,
            'dosage': med.dosage ?? '',
          }),
          _nextInstanceOf(hour, minute),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          // Wall-clock, not absolute: an 08:00 dose stays 08:00 across DST
          // and timezone changes.
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
          matchDateTimeComponents: DateTimeComponents.time, // repeat daily
        );
      }
    }
    return true;
  }

  Future<void> scheduleAppointmentReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required Translations t,
  }) async {
    await _ensureTimezone();
    final prefs = await getReminderPrefs();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details(prefs, t.t('reminders.channelName')),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}
