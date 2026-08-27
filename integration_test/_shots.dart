import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:medremind/data/services/notification_service.dart';
import 'package:medremind/main.dart' as app;

/// Screenshot walk-through: signs in, then rests on each tab long enough for
/// `xcrun simctl io screenshot` to capture it. Not part of the test suite.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> hold(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('walk the tabs', (tester) async {
    NotificationScheduler.suppressPermissionPrompt = true;
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    if (find.byType(TextField).evaluate().length >= 2) {
      await tester.enterText(find.byType(TextField).first, 'quan@medremind.vn');
      await tester.enterText(find.byType(TextField).last, 'MedRemind@2026');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log in').last);
      await hold(tester, 20);
    }

    // Home
    await hold(tester, 14);

    Future<void> goTo(IconData icon) async {
      final target = find.byIcon(icon);
      if (target.evaluate().isEmpty) return;
      await tester.tap(target);
      await hold(tester, 14);
    }

    await goTo(Icons.description_outlined);   // Prescriptions
    await goTo(Icons.schedule_outlined);      // Schedule
    await goTo(Icons.person_outline);         // Profile
  }, timeout: const Timeout(Duration(minutes: 6)));
}
