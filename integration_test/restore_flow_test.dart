import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/data/services/notification_service.dart';
import 'package:medremind/main.dart' as app;

/// Signs into the demo account against the live backend and checks the
/// restored data renders once. Restore used to double every dose: backups
/// carry dose logs with no schedule_time_id, the lazy day-filler could not
/// recognise them, and each medication showed twice on Home and Schedule.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a restored account shows each dose exactly once',
      (tester) async {
    const settings = SettingsRepository();
    await AppDatabase.instance.db;
    await settings.set(SettingsKeys.authToken, '');
    await settings.set(SettingsKeys.seenWelcome, 'true');
    await settings.set(SettingsKeys.askedNotifications, 'true');
    NotificationScheduler.suppressPermissionPrompt = true;

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Settings → sign in with the demo account.
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Sign in or create an account'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Sign in or create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, 'quan@medremind.vn');
    await tester.enterText(find.byType(TextField).last, 'MedRemind@2026');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in').last);

    // Restore downloads the backup; wait until the signed-in Settings shows.
    var signedIn = false;
    for (var i = 0; i < 90 && !signedIn; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      signedIn = find.text('Log out').evaluate().isNotEmpty;
    }
    expect(signedIn, isTrue, reason: 'sign-in with restore completed');

    // Assert against the database itself — the same store the Home and
    // Schedule screens render from. The demo account has four dose times
    // (Metformin 07:30 & 19:30, Amlodipin 08:00, Atorvastatin 21:00); the
    // dedupe bug produced eight.
    final userId = int.parse(
        (await settings.get(SettingsKeys.accountUserId))!);
    final patient = await const PatientsRepository().getPatientByAccount(
        userId);
    expect(patient, isNotNull, reason: 'restore created the profile');

    final today =
        await const DosesRepository().getDosesForDay(patient!.id);
    final seen = <String>{};
    for (final d in today) {
      expect(seen.add('${d.medicationId}-${d.time}'), isTrue,
          reason: 'duplicate dose for ${d.medicationName} at ${d.time}');
    }
    expect(today.length, 4,
        reason: 'exactly one dose per scheduled time, none doubled');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
