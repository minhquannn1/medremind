import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:medremind/features/api_config.dart';
import 'package:medremind/features/auth/patient_auth.dart';
import 'package:medremind/features/scan/ai_scanner.dart';

/// Network-layer tests use a stub client so they are deterministic and offline.
/// They assert the exact response shapes the live Railway backend returns.
void main() {
  group('api config', () {
    test('derives the API base from the scan URL', () {
      expect(apiBase.endsWith('/api'), isTrue,
          reason: 'auth, backup and sync all hang off this root');
      expect(apiBase.contains('scan-prescription'), isFalse);
    });
  });

  group('PatientAuthApi', () {
    test('login success returns the token and account', () async {
      // Captured rather than asserted inside the stub: a failed expectation
      // there would surface as a bogus "network error" instead of a clear fail.
      String? path;
      Map<String, Object?>? sent;

      final api = PatientAuthApi(
        client: MockClient((req) async {
          path = req.url.path;
          sent = jsonDecode(req.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'ok': true,
              'token': 'jwt-token',
              'userId': 7,
              'name': 'Quan Nguyen',
            }),
            200,
          );
        }),
      );

      final res = await api.login(' A@b.com ', 'secret');
      expect(res.ok, isTrue);
      expect(res.token, 'jwt-token');
      expect(res.account!.userId, 7);
      expect(res.account!.name, 'Quan Nguyen');

      expect(path, '/api/patient/login');
      expect(sent!['email'], 'A@b.com',
          reason: 'sent trimmed but not lower-cased, matching the RN client');
      expect(res.account!.email, 'a@b.com',
          reason: 'the local account record is lower-cased');
    });

    test('wrong password maps 401 to invalidCredentials', () async {
      final api = PatientAuthApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'ok': false, 'error': 'invalid_credentials'}),
              401,
            )),
      );
      final res = await api.login('a@b.com', 'nope');
      expect(res.ok, isFalse);
      expect(res.error, AuthErrorCode.invalidCredentials);
    });

    test('deleted account maps 410 to its own code', () async {
      final api = PatientAuthApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'ok': false, 'error': 'account_deleted'}),
              410,
            )),
      );
      final res = await api.login('gone@b.com', 'x');
      expect(res.error, AuthErrorCode.accountDeleted);
    });

    test('register maps email_taken and weak_password', () async {
      final taken = PatientAuthApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'ok': false, 'error': 'email_taken'}), 409)),
      );
      expect((await taken.register('a@b.com', 'password1', 'A')).error,
          AuthErrorCode.emailTaken);

      final weak = PatientAuthApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'ok': false, 'error': 'weak_password'}), 400)),
      );
      expect((await weak.register('a@b.com', 'short', 'A')).error,
          AuthErrorCode.weakPassword);
    });

    test('a rate-limit or unknown error falls back to network', () async {
      final api = PatientAuthApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'ok': false, 'error': 'too_many_requests'}), 429)),
      );
      expect((await api.login('a@b.com', 'x')).error, AuthErrorCode.network);
    });

    test('a non-JSON body does not crash the app', () async {
      final api = PatientAuthApi(
        client: MockClient((_) async => http.Response('<html>502</html>', 502)),
      );
      final res = await api.login('a@b.com', 'x');
      expect(res.ok, isFalse);
      expect(res.error, AuthErrorCode.network);
    });

    test('a connection failure is reported as network, not thrown', () async {
      final api = PatientAuthApi(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );
      final res = await api.login('a@b.com', 'x');
      expect(res.ok, isFalse);
      expect(res.error, AuthErrorCode.network);
    });

    test('deleteAccount sends the bearer token and pair code', () async {
      String? auth;
      Map<String, Object?>? body;
      final api = PatientAuthApi(
        client: MockClient((req) async {
          auth = req.headers['Authorization'];
          body = jsonDecode(req.body) as Map<String, Object?>;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      expect(await api.deleteAccount('tok', 'MED-ABC123'), isTrue);
      expect(auth, 'Bearer tok');
      expect(body!['pairCode'], 'MED-ABC123');
    });

    test('deleteAccount returns false when the server rejects', () async {
      final api = PatientAuthApi(
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      expect(await api.deleteAccount('bad', null), isFalse);
    });

    test('every error code has a translation key', () {
      for (final code in AuthErrorCode.values) {
        expect(authErrorMessageKey(code), startsWith('auth.'));
      }
    });
  });

  group('AiScannerApi', () {
    test('parses a full prescription response', () async {
      final api = AiScannerApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'doctorName': 'BS Nguyen',
                'clinic': 'BV Bach Mai',
                'issuedDate': '2026-07-20',
                'rawText': 'Paracetamol 500mg',
                'medications': [
                  {
                    'name': 'Paracetamol 500mg',
                    'form': 'tablet',
                    'dosage': '1 vien',
                    'frequencyPerDay': 3,
                    'times': ['08:00', '13:00', '20:00'],
                    'relationToMeal': 'after',
                    'durationDays': 5,
                    'quantityTotal': 15,
                    'uses': 'Giam dau, ha sot.',
                  }
                ],
              }),
              200,
            )),
      );

      final res = await api.scanPrescriptionImage('BASE64');
      expect(res.ok, isTrue);
      expect(res.doctorName, 'BS Nguyen');
      expect(res.medications.single.name, 'Paracetamol 500mg');
      expect(res.medications.single.times, ['08:00', '13:00', '20:00']);
      expect(res.medications.single.frequencyPerDay, 3);
      expect(res.medications.single.uses, 'Giam dau, ha sot.');
    });

    test('an unreadable image returns ok with no medications', () async {
      final api = AiScannerApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'rawText': 'khong doc duoc', 'medications': []}),
              200,
            )),
      );
      final res = await api.scanPrescriptionImage('BASE64');
      expect(res.ok, isTrue);
      expect(res.medications, isEmpty);
      expect(res.rawText, 'khong doc duoc');
    });

    test('missing fields default instead of throwing', () async {
      final api = AiScannerApi(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final res = await api.scanPrescriptionImage('BASE64');
      expect(res.ok, isTrue);
      expect(res.doctorName, '');
      expect(res.medications, isEmpty);
    });

    test('a 500 is reported as a server error', () async {
      final api = AiScannerApi(
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      final res = await api.scanPrescriptionImage('BASE64');
      expect(res.ok, isFalse);
      expect(res.error, ScanErrorCode.server);
    });

    test('sends the image, media type and language', () async {
      Map<String, Object?>? sent;
      final api = AiScannerApi(
        client: MockClient((req) async {
          sent = jsonDecode(req.body) as Map<String, Object?>;
          return http.Response(jsonEncode({'medications': []}), 200);
        }),
      );
      await api.scanPrescriptionImage('IMG', mediaType: 'image/png', lang: 'en');
      expect(sent!['imageBase64'], 'IMG');
      expect(sent!['mediaType'], 'image/png');
      expect(sent!['lang'], 'en');
    });

    test('explainMedication returns text, or null when empty', () async {
      final good = AiScannerApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'explanation': 'Ha huyet ap.'}), 200)),
      );
      expect(await good.explainMedication('Amlodipin'), 'Ha huyet ap.');

      final blank = AiScannerApi(
        client: MockClient((_) async =>
            http.Response(jsonEncode({'explanation': '   '}), 200)),
      );
      expect(await blank.explainMedication('X'), isNull);

      final failed = AiScannerApi(
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      expect(await failed.explainMedication('X'), isNull);
    });

    test('every scan error code has a translation key', () {
      for (final code in ScanErrorCode.values) {
        expect(scanErrorMessageKey(code), startsWith('scan.'));
      }
    });
  });
}

/// Stand-in for a dropped connection; MockClient just needs something to throw.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
