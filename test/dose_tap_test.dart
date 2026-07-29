import 'package:flutter_test/flutter_test.dart';

import 'package:medremind/features/notifications/scheduler.dart';

void main() {
  group('DoseTapPayload', () {
    test('round-trips through the notification payload', () {
      const original = DoseTapPayload(medicationId: 42, time: '08:30');
      final decoded = DoseTapPayload.decode(original.encode());

      expect(decoded, isNotNull);
      expect(decoded!.medicationId, 42);
      expect(decoded.time, '08:30');
    });

    test('a missing or empty payload yields null', () {
      expect(DoseTapPayload.decode(null), isNull);
      expect(DoseTapPayload.decode(''), isNull);
    });

    test('malformed payloads are rejected instead of crashing the tap', () {
      expect(DoseTapPayload.decode('not json'), isNull);
      expect(DoseTapPayload.decode('{"time":"08:00"}'), isNull,
          reason: 'no medicationId');
      expect(DoseTapPayload.decode('{"medicationId":1}'), isNull,
          reason: 'no time');
      expect(DoseTapPayload.decode('[1,2,3]'), isNull);
    });

    test('accepts a numeric id arriving as a double', () {
      final decoded =
          DoseTapPayload.decode('{"medicationId":7.0,"time":"20:00"}');
      expect(decoded?.medicationId, 7);
    });
  });
}
