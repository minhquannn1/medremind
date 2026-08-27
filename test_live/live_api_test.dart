import 'package:flutter_test/flutter_test.dart';

import 'package:medremind/data/services/api_config.dart';
import 'package:medremind/data/services/patient_auth_service.dart';
import 'package:medremind/data/services/ai_scanner_service.dart';

/// Live checks against the real Railway backend.
///
/// Deliberately outside `test/` so `flutter test` (offline, deterministic)
/// never picks them up. Run explicitly:
///
///   flutter test test_live/
///
/// These prove the ported Dart client speaks the same protocol as the React
/// Native one against the running server — something no stub can establish.
void main() {
  const auth = PatientAuthApi();

  test('backend base URL points at the deployed API', () {
    expect(apiBase, contains('medremind-backend-production'));
    expect(apiBase, endsWith('/api'));
  });

  test('the demo patient account signs in', () async {
    final res = await auth.login('quan@medremind.vn', 'MedRemind@2026');
    expect(res.ok, isTrue, reason: 'error was ${res.error?.name}');
    expect(res.token, isNotEmpty);
    expect(res.account!.name, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a wrong password is rejected with invalidCredentials', () async {
    final res = await auth.login('quan@medremind.vn', 'definitely-wrong');
    expect(res.ok, isFalse);
    expect(res.error, AuthErrorCode.invalidCredentials);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('registering an existing address returns emailTaken', () async {
    final res =
        await auth.register('quan@medremind.vn', 'MedRemind@2026', 'Dup');
    expect(res.ok, isFalse);
    expect(res.error, AuthErrorCode.emailTaken);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('the scan endpoint answers without throwing', () async {
    const scanner = AiScannerApi();
    final res = await scanner.scanPrescriptionImage('not-a-real-image');
    // Either outcome is fine — the point is a clean, typed response.
    expect(res.ok || res.error != null, isTrue);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
