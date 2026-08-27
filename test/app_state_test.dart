import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/backup_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/data/services/backup_sync_service.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/data/services/notification_service.dart';
import 'package:medremind/data/services/patient_auth_service.dart';
import 'package:medremind/ui/core/app_state.dart';

/// Session rules. The App Store rejected version 1.0 (3) under Guideline
/// 5.1.1(v) because the app demanded a sign-in before anything worked, so
/// these pin down that launching without an account still lands in the app.
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

  const patients = PatientsRepository();

  // load() with no stored token never reaches the network or the notification
  // plugin, so the real collaborators are safe here and keep the test honest.
  AppStateNotifier build() {
    final sync = BackupSyncApi();
    addTearDown(sync.dispose);
    return AppStateNotifier(
      settings: const SettingsRepository(),
      patients: patients,
      backups: const BackupRepository(),
      auth: const PatientAuthApi(),
      backupSync: sync,
      notifications: NotificationScheduler(),
    );
  }

  test('a first launch with no account is ready and unonboarded', () async {
    final notifier = build();
    await notifier.load();

    expect(notifier.state.ready, isTrue);
    expect(notifier.state.authed, isFalse);
    expect(notifier.state.onboarded, isFalse,
        reason: 'sends the user to onboarding, not to a login wall');
    expect(notifier.state.activePatientId, isNull);
  });

  test('a local profile is picked up without signing in', () async {
    final id = await patients.createPatient(fullName: 'Quan');

    final notifier = build();
    await notifier.load();

    expect(notifier.state.ready, isTrue);
    expect(notifier.state.authed, isFalse);
    expect(notifier.state.onboarded, isTrue,
        reason: 'the app opens on the local profile with no account');
    expect(notifier.state.activePatientId, id);
  });

  test('a profile owned by an account is not opened by a signed-out launch',
      () async {
    await patients.createPatient(
      fullName: 'Quan',
      accountUserId: 7,
      accountEmail: 'a@b.com',
    );

    final notifier = build();
    await notifier.load();

    expect(notifier.state.onboarded, isFalse);
    expect(notifier.state.activePatientId, isNull);
  });
}
