import 'package:flutter/foundation.dart';

import 'package:medremind/data/services/web_push/push_status_api.dart';
import 'package:medremind/data/services/web_push/web_push.dart' as web_push;

typedef TokenReader = Future<String?> Function();
typedef PushEnabler = Future<String> Function(String token, String lang,
    {bool onlyIfGranted});

/// Web-only: whether THIS browser gets dose reminders, with the two actions
/// that make it true — subscribe, and prove delivery with a test push.
///
/// Exists because the one unverifiable link in web push is the final hop to a
/// real device; users kept granting permission during a broken flow and had
/// no way to see that no subscription was ever stored.
class WebPushViewModel extends ChangeNotifier {
  WebPushViewModel({
    required this.readToken,
    required this.lang,
    this.api = const PushStatusApi(),
    PushEnabler? enabler,
  }) : enabler = enabler ?? web_push.enableWebPush;

  final TokenReader readToken;
  final String lang;
  final PushStatusApi api;
  final PushEnabler enabler;

  /// Subscribed browser count for the account; null = unknown/loading.
  int? _count;
  int? get count => _count;

  bool _busy = false;
  bool get busy => _busy;

  /// i18n key describing the last action's outcome, or null.
  String? _messageKey;
  String? get messageKey => _messageKey;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return;
    _count = await api.subscriptionCount(token);
    _notify();
  }

  /// Subscribes this browser (prompting if needed), then re-reads the count.
  Future<void> enableHere() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return;

    _busy = true;
    _messageKey = null;
    _notify();

    final result = await enabler(token, lang, onlyIfGranted: false);
    _messageKey = switch (result) {
      'enabled' => 'settings.webPushEnabled',
      'denied' => 'settings.webPushDenied',
      'unsupported' => 'settings.webPushUnsupported',
      _ => 'settings.webPushFailed',
    };
    await refresh();
    _busy = false;
    _notify();
  }

  /// Fires a real push at every subscribed browser, this one included.
  Future<void> sendTest() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return;

    _busy = true;
    _messageKey = null;
    _notify();

    final delivered = await api.sendTest(token, lang);
    _messageKey = delivered == null
        ? 'settings.webPushFailed'
        : delivered > 0
            ? 'settings.webPushTestSent'
            : 'settings.webPushNoDevices';
    _busy = false;
    _notify();
  }
}
