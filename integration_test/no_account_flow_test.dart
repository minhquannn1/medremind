import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:medremind/data/services/notification_service.dart';
import 'package:medremind/main.dart' as app;

/// App Store Guideline 5.1.1(v): version 1.0 (3) was rejected because the app
/// demanded an account before anything worked. This walks the path a reviewer
/// takes on a fresh install — no sign-in anywhere — and asserts it ends inside
/// the app rather than on a login screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a reviewer reaches the app without ever signing in',
      (tester) async {
    NotificationScheduler.suppressPermissionPrompt = true;
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // A fresh install lands straight in the app: no login screen, and no form
    // asking for a name, date of birth, gender, height or weight.
    expect(find.text('Log in'), findsNothing);
    expect(find.text('Create your profile'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    // The medical disclaimer is still put in front of the user on first run
    // (App Review guideline 1.4.1), and is dismissible.
    expect(find.textContaining('does not diagnose'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not diagnose'), findsNothing);

    // Landed in the tab shell with every tab reachable, still signed out.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Prescriptions'), findsWidgets);
    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);

    // Settings offers the account rather than demanding it, and the actions
    // that need one are not shown to a signed-out user.
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Sign in or create an account'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Delete account'), findsNothing);
  });
}
