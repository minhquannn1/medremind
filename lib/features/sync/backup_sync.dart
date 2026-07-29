import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../db/repositories/backup_repository.dart';
import '../../db/repositories/settings_repository.dart';
import '../api_config.dart';

/// Cloud backup: uploads a full JSON export of the local database and restores
/// it on a new device. Ported from `src/features/sync/backup.ts`.
class BackupSyncApi {
  BackupSyncApi({
    http.Client? client,
    this.settings = const SettingsRepository(),
    this.backups = const BackupRepository(),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final SettingsRepository settings;
  final BackupRepository backups;

  static const Duration _debounce = Duration(seconds: 5);
  Timer? _pending;

  /// Uploads a full export of the patient's data. No-op when signed out.
  Future<bool> backupNow(int patientId) async {
    final token = await settings.get(SettingsKeys.authToken);
    if (token == null || token.isEmpty) return false;

    final data = await backups.exportPatientData(patientId);
    if (data == null) return false;

    try {
      final res = await _client
          .put(
            Uri.parse('$apiBase/patient/backup'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'bypass-tunnel-reminder': 'true',
            },
            body: jsonEncode({'data': data.toJson()}),
          )
          .timeout(const Duration(seconds: 30));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Schedules a backup shortly after the current burst of data changes.
  /// Fire-and-forget: failures are silent and retried on the next change.
  void queueBackup(int patientId) {
    _pending?.cancel();
    _pending = Timer(_debounce, () {
      _pending = null;
      unawaited(backupNow(patientId));
    });
  }

  void dispose() {
    _pending?.cancel();
    _pending = null;
  }

  /// Downloads the account's backup, or null when none exists / on error.
  Future<PatientDataExport?> fetchServerBackup(String token) async {
    try {
      final res = await _client.get(
        Uri.parse('$apiBase/patient/backup'),
        headers: {
          'Authorization': 'Bearer $token',
          'bypass-tunnel-reminder': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final body = jsonDecode(res.body) as Map<String, Object?>;
      if (body['ok'] != true) return null;
      final data = body['data'];
      if (data is! Map) return null;

      return PatientDataExport.fromJson(data.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }
}
