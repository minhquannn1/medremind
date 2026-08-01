import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/settings_repository.dart';

/// Reminder preferences and the account actions.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required this.applyReminderPrefs,
    required this.deleteAccount,
    required this.signOut,
    this.settings = const SettingsRepository(),
  });

  final SettingsRepository settings;

  /// Re-applies the Android channel and reschedules, injected so this class
  /// stays free of platform calls.
  final Future<void> Function() applyReminderPrefs;
  final Future<bool> Function() deleteAccount;
  final Future<void> Function() signOut;

  bool _sound = true;
  bool get sound => _sound;

  bool _vibration = true;
  bool get vibration => _vibration;

  bool _deleting = false;
  bool get deleting => _deleting;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _sound = await settings.getBool(SettingsKeys.reminderSound, true);
    _vibration = await settings.getBool(SettingsKeys.reminderVibration, true);
    _notify();
  }

  Future<void> setSound(bool value) async {
    _sound = value;
    _notify();
    await settings.set(SettingsKeys.reminderSound, '$value');
    await applyReminderPrefs();
  }

  Future<void> setVibration(bool value) async {
    _vibration = value;
    _notify();
    await settings.set(SettingsKeys.reminderVibration, '$value');
    await applyReminderPrefs();
  }

  /// Returns false when the server refused, so the view can say so instead of
  /// silently leaving the user signed in.
  Future<bool> confirmDelete() async {
    _deleting = true;
    _notify();
    final ok = await deleteAccount();
    _deleting = false;
    _notify();
    return ok;
  }
}
