import 'package:sqflite/sqflite.dart';

import '../database.dart';

/// Key/value settings table. Ported from `src/db/repositories/settings.ts`.
/// Keys are kept byte-identical to the RN app so a restored database keeps
/// its session, language and doctor pairing.
class SettingsKeys {
  static const language = 'language';
  static const activePatientId = 'active_patient_id';
  static const onboarded = 'onboarded';
  static const reminderSound = 'reminder_sound';
  static const reminderVibration = 'reminder_vibration';
  static const doctorPairCode = 'doctor_pair_code';
  static const doctorName = 'doctor_name';
  static const authToken = 'auth_token';
  static const accountUserId = 'account_user_id';
  static const accountEmail = 'account_email';
  static const accountName = 'account_name';
  static const askedNotifications = 'asked_notifications';
}

class SettingsRepository {
  const SettingsRepository();

  Future<String?> get(String key) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final database = await AppDatabase.instance.db;
    await database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, bool fallback) async {
    final v = await get(key);
    if (v == null) return fallback;
    return v == 'true';
  }
}
