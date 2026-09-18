/// Backend endpoint configuration.
///
/// Mirrors `src/features/scan/aiScanner.ts`: one base URL drives the scan,
/// auth, backup and doctor-sync calls. Override at build time with
/// `--dart-define=SCAN_API_URL=https://.../api/scan-prescription`, which is the
/// Flutter equivalent of the RN `EXPO_PUBLIC_SCAN_API_URL` env var.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

const String _defaultScanUrl =
    'https://medremind-backend-production.up.railway.app/api/scan-prescription';

/// On the web the app is served by the same server that hosts the API, so the
/// base is the page's own origin. Hardcoding the Railway URL there broke on
/// any other origin (localhost, a future custom domain) via CSP and CORS; the
/// mobile apps keep the absolute URL since they have no origin of their own.
/// An explicit --dart-define=SCAN_API_URL still wins everywhere.
const String _envScanUrl = String.fromEnvironment('SCAN_API_URL');

final String scanApiUrl = _envScanUrl.isNotEmpty
    ? _envScanUrl
    : (kIsWeb ? '${Uri.base.origin}/api/scan-prescription' : _defaultScanUrl);

/// Everything else hangs off the same `/api` root.
final String apiBase =
    scanApiUrl.replaceFirst(RegExp(r'/scan-prescription/?$'), '');

const Duration requestTimeout = Duration(seconds: 20);
const Duration scanTimeout = Duration(seconds: 60);
