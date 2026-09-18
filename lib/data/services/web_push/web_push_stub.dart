/// Non-web platforms: dose reminders come from flutter_local_notifications,
/// so browser push is simply not available here.
Future<String> enableWebPush(
  String token,
  String lang, {
  bool onlyIfGranted = false,
}) async =>
    'unsupported';

Future<String> disableWebPush(String token) async => 'unsupported';
