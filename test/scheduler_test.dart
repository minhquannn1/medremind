import 'package:flutter_test/flutter_test.dart';

import 'package:medremind/features/notifications/scheduler.dart';

void main() {
  group('notificationId', () {
    test('is stable for the same medication and time', () {
      expect(
        NotificationScheduler.notificationId(12, 8, 30),
        NotificationScheduler.notificationId(12, 8, 30),
      );
    });

    test('differs per time within one medication', () {
      final morning = NotificationScheduler.notificationId(12, 8, 0);
      final evening = NotificationScheduler.notificationId(12, 20, 0);
      expect(morning, isNot(evening),
          reason: 'two daily doses must not overwrite each other');
    });

    test('differs across medications at the same time', () {
      expect(
        NotificationScheduler.notificationId(1, 8, 0),
        isNot(NotificationScheduler.notificationId(2, 8, 0)),
      );
    });

    test('never collides across a realistic id and time space', () {
      final seen = <int>{};
      for (var med = 1; med <= 300; med++) {
        for (var hour = 0; hour < 24; hour++) {
          for (final minute in [0, 15, 30, 45]) {
            final id = NotificationScheduler.notificationId(med, hour, minute);
            expect(seen.add(id), isTrue,
                reason: 'collision for med $med at $hour:$minute');
          }
        }
      }
    });

    test('stays inside the 32-bit platform id range', () {
      final id = NotificationScheduler.notificationId(999999, 23, 59);
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    });
  });
}
