import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';

/// Sends a prescription image to the backend proxy, which calls the vision
/// model and returns structured medication data. The API key lives only on the
/// server — never in the app bundle.
/// Ported from `src/features/scan/aiScanner.ts`.

class ScannedMedication {
  final String name;
  final String? form;
  final String? dosage;
  final int? frequencyPerDay;
  final List<String> times;
  final String? relationToMeal;
  final String? takeWith;
  final int? durationDays;
  final double? quantityTotal;
  final String? notes;

  /// AI plain-language "what this medicine is for", in the app language.
  final String? uses;

  const ScannedMedication({
    required this.name,
    this.form,
    this.dosage,
    this.frequencyPerDay,
    this.times = const [],
    this.relationToMeal,
    this.takeWith,
    this.durationDays,
    this.quantityTotal,
    this.notes,
    this.uses,
  });

  factory ScannedMedication.fromJson(Map<String, Object?> j) =>
      ScannedMedication(
        name: (j['name'] as String?) ?? '',
        form: j['form'] as String?,
        dosage: j['dosage'] as String?,
        frequencyPerDay: (j['frequencyPerDay'] as num?)?.toInt(),
        times: (j['times'] as List?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const [],
        relationToMeal: j['relationToMeal'] as String?,
        takeWith: j['takeWith'] as String?,
        durationDays: (j['durationDays'] as num?)?.toInt(),
        quantityTotal: (j['quantityTotal'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
        uses: j['uses'] as String?,
      );
}

enum ScanErrorCode { network, server, timeout }

/// The i18n key shown to the user for [code].
String scanErrorMessageKey(ScanErrorCode code) {
  switch (code) {
    case ScanErrorCode.network:
      return 'scan.networkError';
    case ScanErrorCode.server:
      return 'scan.serverError';
    case ScanErrorCode.timeout:
      return 'scan.timeout';
  }
}

class ScanResult {
  final bool ok;
  final ScanErrorCode? error;
  final String doctorName;
  final String clinic;
  final String issuedDate;
  final String rawText;
  final List<ScannedMedication> medications;

  const ScanResult.success({
    required this.doctorName,
    required this.clinic,
    required this.issuedDate,
    required this.rawText,
    required this.medications,
  })  : ok = true,
        error = null;

  const ScanResult.failure(this.error)
      : ok = false,
        doctorName = '',
        clinic = '',
        issuedDate = '',
        rawText = '',
        medications = const [];

  factory ScanResult.fromJson(Map<String, Object?> j) => ScanResult.success(
        doctorName: (j['doctorName'] as String?) ?? '',
        clinic: (j['clinic'] as String?) ?? '',
        issuedDate: (j['issuedDate'] as String?) ?? '',
        rawText: (j['rawText'] as String?) ?? '',
        medications: (j['medications'] as List?)
                ?.whereType<Map>()
                .map((m) => ScannedMedication.fromJson(m.cast<String, Object?>()))
                .toList() ??
            const [],
      );
}

class AiScannerApi {
  const AiScannerApi({this.client});

  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  Future<ScanResult> scanPrescriptionImage(
    String imageBase64, {
    String mediaType = 'image/jpeg',
    String lang = 'vi',
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse(scanApiUrl),
            headers: const {
              'Content-Type': 'application/json',
              'bypass-tunnel-reminder': 'true',
            },
            body: jsonEncode({
              'imageBase64': imageBase64,
              'mediaType': mediaType,
              'lang': lang,
            }),
          )
          .timeout(scanTimeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return const ScanResult.failure(ScanErrorCode.server);
      }

      final data = jsonDecode(res.body) as Map<String, Object?>;
      return ScanResult.fromJson(data);
    } on TimeoutException {
      return const ScanResult.failure(ScanErrorCode.timeout);
    } catch (_) {
      return const ScanResult.failure(ScanErrorCode.network);
    }
  }

  /// Plain-language explanation of one medicine, used by the detail screen.
  /// Ported from `src/features/medication/explainMedication.ts`.
  Future<String?> explainMedication(String name, {String lang = 'vi'}) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiBase/explain-medication'),
            headers: const {
              'Content-Type': 'application/json',
              'bypass-tunnel-reminder': 'true',
            },
            body: jsonEncode({'name': name, 'lang': lang}),
          )
          .timeout(requestTimeout);

      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final data = jsonDecode(res.body) as Map<String, Object?>;
      final text = data['explanation'] as String?;
      if (text == null || text.trim().isEmpty) return null;
      return text;
    } catch (_) {
      return null;
    }
  }
}
