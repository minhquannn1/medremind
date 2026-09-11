import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/data/services/notification_service.dart';
import 'package:medremind/data/services/patient_auth_service.dart';
import 'package:medremind/main.dart' as app;

/// End-to-end run of the real app on a simulator or device.
///
///   flutter test integration_test/app_flow_test.dart -d DEVICE_ID
///
/// Signs in against the live backend, so it proves the whole stack — UI,
/// state, network, SQLite — works together on an actual device, which no
/// widget test can show. Build 1.0 (9) was rejected because tapping Log in
/// showed an error (Guideline 2.1(a)); these walk that exact path.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const auth = PatientAuthApi();
  const settings = SettingsRepository();

  setUp(() async {
    // Start signed out, with the walkthrough already seen: these tests are
    // about the login flow, not the first run.
    await AppDatabase.instance.db;
    await settings.set(SettingsKeys.authToken, '');
    await settings.set(SettingsKeys.accountUserId, '');
    await settings.set(SettingsKeys.accountEmail, '');
    await settings.set(SettingsKeys.seenWelcome, 'true');
    await settings.set(SettingsKeys.askedNotifications, 'true');
  });

  /// Login is optional, so it lives behind Settings → Account. This walks
  /// there the way a user (or reviewer) does.
  Future<void> openLoginScreen(WidgetTester tester) async {
    NotificationScheduler.suppressPermissionPrompt = true;
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

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

    expect(find.byType(TextField), findsNWidgets(2),
        reason: 'email + password');
  }

  testWidgets('a wrong password is explained, not blamed on the network',
      (tester) async {
    await openLoginScreen(tester);

    await tester.enterText(find.byType(TextField).first, 'quan@medremind.vn');
    await tester.enterText(find.byType(TextField).last, 'wrong-password');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log in').last);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Stays on the auth screen and explains why. The 2.1(a) rejection was
    // this path showing "check your connection" on a working connection.
    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(find.textContaining('connection'), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('a valid sign-in leaves the auth screen', (tester) async {
    // A throwaway account: it has no cloud backup, so sign-in does not enter
    // the restore branch that pops an unautomatable iOS permission dialog.
    // Deleted again at the end, which also exercises account deletion.
    final email =
        'e2e-${DateTime.now().millisecondsSinceEpoch}@medremind-test.com';
    const password = 'E2eTest!2026';

    final created = await auth.register(email, password, 'E2E Test');
    expect(created.ok, isTrue, reason: 'setup failed: ${created.error?.name}');
    final token = created.token!;

    // Register signed the account in on the server only; the app must still
    // start from a signed-out state.
    await settings.set(SettingsKeys.authToken, '');

    await openLoginScreen(tester);

    await tester.enterText(find.byType(TextField).first, email);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in').last);

    // Not pumpAndSettle: the destination screens show a progress spinner
    // while they load, and an always-animating widget never settles.
    var movedOn = false;
    for (var i = 0; i < 60 && !movedOn; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      // Success pops back to Settings, which now shows the signed-in
      // account with its Log out button.
      movedOn = find.byType(TextField).evaluate().isEmpty &&
          find.text('Log out').evaluate().isNotEmpty;
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
