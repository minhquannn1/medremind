import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:medremind/db/database.dart';
import 'package:medremind/db/repositories/settings_repository.dart';
import 'package:medremind/features/auth/patient_auth.dart';
import 'package:medremind/main.dart' as app;

/// End-to-end run of the real app on a simulator or device.
///
///   flutter test integration_test/app_flow_test.dart -d DEVICE_ID
///
/// Signs in against the live backend, so it proves the whole stack — UI,
/// state, network, SQLite, notification scheduling — works together on an
/// actual device, which no widget test can show.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const auth = PatientAuthApi();
  const settings = SettingsRepository();

  setUp(() async {
    // Start every run signed out so the login screen is the entry point.
    await AppDatabase.instance.db;
    await settings.set(SettingsKeys.authToken, '');
    await settings.set(SettingsKeys.accountUserId, '');
    await settings.set(SettingsKeys.accountEmail, '');
  });

  testWidgets('login screen renders and rejects a bad password',
      (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byType(TextField), findsNWidgets(2),
        reason: 'email + password');

    await tester.enterText(
        find.byType(TextField).first, 'quan@medremind.vn');
    await tester.enterText(find.byType(TextField).last, 'wrong-password');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log in').last);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Stays on the auth screen and explains why.
    expect(find.text('Wrong email or password.'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('a valid sign-in leaves the auth screen', (tester) async {
    // A throwaway account: it has no cloud backup, so sign-in does not enter
    // the restore branch that pops an unautomatable iOS permission dialog.
    // Deleted again at the end, which also exercises account deletion.
    final email =
        'e2e-${DateTime.now().millisecondsSinceEpoch}@medremind-test.com';
    const password = 'E2eTest!2026';

    final created = await auth.register(email, password, 'E2E Test');
    expect(created.ok, isTrue,
        reason: 'setup failed: ${created.error?.name}');
    final token = created.token!;

    // Register signed the account in on the server only; the app must still
    // start from a signed-out state.
    await settings.set(SettingsKeys.authToken, '');

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.enterText(find.byType(TextField).first, email);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in').last);

    // Not pumpAndSettle: the destination screens show a progress spinner
    // while they load, and an always-animating widget never settles.
    var movedOn = false;
    for (var i = 0; i < 60 && !movedOn; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      movedOn = find.text('Create your profile').evaluate().isNotEmpty ||
          find.byType(NavigationBar).evaluate().isNotEmpty;
    }

    final onScreen = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .toList();

    // Clean up before asserting so a failure never leaks an account.
    await auth.deleteAccount(token, null);

    expect(movedOn, isTrue,
        reason: 'still on the login screen after a valid sign-in. '
            'Visible text: $onScreen');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
