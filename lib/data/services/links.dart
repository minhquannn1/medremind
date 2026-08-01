import 'package:url_launcher/url_launcher.dart';

import 'package:medremind/data/services/api_config.dart';

/// Public legal pages, served by the same backend as the API.
/// Their URLs are what App Store Connect's Privacy Policy and Support fields
/// point at, so they must stay reachable.
final String _siteBase = apiBase.replaceFirst(RegExp(r'/api/?$'), '');

String get privacyPolicyUrl => '$_siteBase/privacy';
String get supportUrl => '$_siteBase/support';
String get termsUrl => '$_siteBase/terms';

/// Opens [url] in the system browser. Returns false when the platform refuses,
/// so callers can tell the user instead of appearing to do nothing.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
