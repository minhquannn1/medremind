import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:medremind/data/services/api_config.dart';

/// Subscription state as the server sees it, plus the one probe no automated
/// test can run: a real push to this very device.
class PushStatusApi {
  const PushStatusApi({this.client});

  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// How many browsers the account has subscribed, or null on failure.
  Future<int?> subscriptionCount(String token) async {
    try {
      final res = await _client
          .get(Uri.parse('$apiBase/push/status'), headers: _headers(token))
          .timeout(requestTimeout);
      final data = jsonDecode(res.body) as Map<String, Object?>;
      if (data['ok'] != true) return null;
      return (data['count'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Sends a test notification; returns how many devices it reached, or null
  /// when the request itself failed.
  Future<int?> sendTest(String token, String lang) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiBase/push/test'),
            headers: _headers(token),
            body: jsonEncode({'lang': lang}),
          )
          .timeout(requestTimeout);
      final data = jsonDecode(res.body) as Map<String, Object?>;
      if (data['ok'] != true) return null;
      return (data['delivered'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }
}
