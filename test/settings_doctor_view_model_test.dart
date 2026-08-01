import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/ui/features/settings/view_models/settings_view_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.close();
    await AppDatabase.instance.openInMemory();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  const settings = SettingsRepository();

  SettingsViewModel build({
    bool deleteSucceeds = true,
    List<String>? calls,
  }) =>
      SettingsViewModel(
        applyReminderPrefs: () async => calls?.add('applyPrefs'),
        deleteAccount: () async {
          calls?.add('delete');
          return deleteSucceeds;
        },
        signOut: () async => calls?.add('signOut'),
      );

  group('reminder preferences', () {
    test('default to on for a fresh install', () async {
      final vm = build();
      await vm.load();
      expect(vm.sound, isTrue);
      expect(vm.vibration, isTrue);
    });

    test('persist and reschedule when toggled', () async {
      final calls = <String>[];
      final vm = build(calls: calls);
      await vm.load();

      await vm.setSound(false);

      expect(vm.sound, isFalse);
      expect(await settings.get(SettingsKeys.reminderSound), 'false');
      expect(calls, contains('applyPrefs'),
          reason: 'queued reminders must pick up the new sound setting');
    });

    test('reload reflects what was stored', () async {
      await settings.set(SettingsKeys.reminderVibration, 'false');
      final vm = build();
      await vm.load();
      expect(vm.vibration, isFalse);
    });

    test('the switch flips before the write, so the UI never lags', () async {
      final vm = build();
      await vm.load();
      final future = vm.setVibration(false);
      expect(vm.vibration, isFalse);
      await future;
    });
  });

  group('account deletion', () {
    test('reports success and clears the busy flag', () async {
      final vm = build();
      expect(await vm.confirmDelete(), isTrue);
      expect(vm.deleting, isFalse);
    });

    test('reports failure so the view can say so', () async {
      final vm = build(deleteSucceeds: false);
      expect(await vm.confirmDelete(), isFalse,
          reason: 'a refused delete must not look like it worked');
      expect(vm.deleting, isFalse);
    });

    test('notifies the view while deleting', () async {
      final vm = build();
      var notifications = 0;
      vm.addListener(() => notifications++);
      await vm.confirmDelete();
      expect(notifications, greaterThanOrEqualTo(2),
          reason: 'one for the spinner, one for finishing');
    });
  });
}
