import 'dart:js_interop';

/// Bridges to `web/push.js`, which owns the browser ceremony: permission
/// prompt, service-worker registration, PushManager subscription, and the
/// subscribe call to the backend.
@JS('medolyPush.enable')
external JSPromise<JSString> _enable(
    JSString token, JSString lang, JSBoolean onlyIfGranted);

@JS('medolyPush.disable')
external JSPromise<JSString> _disable(JSString token);

/// [onlyIfGranted] skips the permission prompt: used at launch, where a
/// prompt would appear with no user gesture and Safari refuses it anyway.
Future<String> enableWebPush(
  String token,
  String lang, {
  bool onlyIfGranted = false,
}) async {
  try {
    return (await _enable(token.toJS, lang.toJS, onlyIfGranted.toJS).toDart)
        .toDart;
  } catch (_) {
    return 'error';
  }
}

Future<String> disableWebPush(String token) async {
  try {
    return (await _disable(token.toJS).toDart).toDart;
  } catch (_) {
    return 'error';
  }
}
