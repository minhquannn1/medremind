/// Backend endpoint configuration.
///
/// Mirrors `src/features/scan/aiScanner.ts`: one base URL drives the scan,
/// auth, backup and doctor-sync calls. Override at build time with
/// `--dart-define=SCAN_API_URL=https://.../api/scan-prescription`, which is the
/// Flutter equivalent of the RN `EXPO_PUBLIC_SCAN_API_URL` env var.
library;

const String _defaultScanUrl =
    'https://medremind-backend-production.up.railway.app/api/scan-prescription';

const String scanApiUrl =
    String.fromEnvironment('SCAN_API_URL', defaultValue: _defaultScanUrl);

/// Everything else hangs off the same `/api` root.
final String apiBase =
    scanApiUrl.replaceFirst(RegExp(r'/scan-prescription/?$'), '');

const Duration requestTimeout = Duration(seconds: 20);
const Duration scanTimeout = Duration(seconds: 60);
