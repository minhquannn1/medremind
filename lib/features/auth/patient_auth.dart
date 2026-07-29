import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';

/// Patient authentication against the backend account database.
/// Ported from `src/features/auth/patientAuth.ts`.

class AuthAccount {
  final int userId;
  final String email;
  final String name;

  const AuthAccount({
    required this.userId,
    required this.email,
    required this.name,
  });
}

enum AuthErrorCode {
  emailTaken,
  invalidCredentials,
  accountDeleted,
  weakPassword,
  missingFields,
  network,
}

AuthErrorCode authErrorFromString(String? code) {
  switch (code) {
    case 'email_taken':
      return AuthErrorCode.emailTaken;
    case 'invalid_credentials':
      return AuthErrorCode.invalidCredentials;
    case 'account_deleted':
      return AuthErrorCode.accountDeleted;
    case 'weak_password':
      return AuthErrorCode.weakPassword;
    case 'missing_fields':
      return AuthErrorCode.missingFields;
    default:
      return AuthErrorCode.network;
  }
}

/// The i18n key that explains [code] to the user.
String authErrorMessageKey(AuthErrorCode code) {
  switch (code) {
    case AuthErrorCode.emailTaken:
      return 'auth.errorEmailTaken';
    case AuthErrorCode.invalidCredentials:
      return 'auth.errorInvalidCredentials';
    case AuthErrorCode.accountDeleted:
      return 'auth.errorAccountDeleted';
    case AuthErrorCode.weakPassword:
      return 'auth.errorWeakPassword';
    case AuthErrorCode.missingFields:
      return 'auth.errorMissingFields';
    case AuthErrorCode.network:
      return 'auth.errorNetwork';
  }
}

class AuthResult {
  final bool ok;
  final String? token;
  final AuthAccount? account;
  final AuthErrorCode? error;

  const AuthResult.success({required this.token, required this.account})
      : ok = true,
        error = null;

  const AuthResult.failure(this.error)
      : ok = false,
        token = null,
        account = null;
}

class PatientAuthApi {
  const PatientAuthApi({this.client});

  /// Injectable so tests can drive the parsing without a network.
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  Future<AuthResult> _post(String path, Map<String, Object?> body) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiBase$path'),
            headers: const {
              'Content-Type': 'application/json',
              'bypass-tunnel-reminder': 'true',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      Map<String, Object?> data;
      try {
        data = jsonDecode(res.body) as Map<String, Object?>;
      } catch (_) {
        data = const {};
      }

      final ok = data['ok'] == true;
      final token = data['token'] as String?;
      final userId = (data['userId'] as num?)?.toInt();

      if (res.statusCode >= 400 || !ok || token == null || userId == null) {
        return AuthResult.failure(
          authErrorFromString(data['error'] as String?),
        );
      }

      return AuthResult.success(
        token: token,
        account: AuthAccount(
          userId: userId,
          email: (body['email'] as String).toLowerCase(),
          name: (data['name'] as String?) ?? '',
        ),
      );
    } on TimeoutException {
      return const AuthResult.failure(AuthErrorCode.network);
    } catch (_) {
      return const AuthResult.failure(AuthErrorCode.network);
    }
  }

  Future<AuthResult> register(String email, String password, String name) =>
      _post('/patient/register', {
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
      });

  Future<AuthResult> login(String email, String password) =>
      _post('/patient/login', {
        'email': email.trim(),
        'password': password,
      });

  /// Permanently deletes the account and all server-side data (backup plus any
  /// doctor-shared snapshot identified by [pairCode]).
  /// Required by App Store Guideline 5.1.1(v).
  Future<bool> deleteAccount(String token, String? pairCode) async {
    try {
      final res = await _client
          .delete(
            Uri.parse('$apiBase/patient/account'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'bypass-tunnel-reminder': 'true',
            },
            body: jsonEncode({'pairCode': pairCode}),
          )
          .timeout(requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
