/// Web Push for dose reminders, PWA only.
///
/// On the web the app cannot schedule local notifications, so the backend
/// pushes at dose times instead — which needs an account, because the server
/// reads the schedule from the account's cloud backup. `enableWebPush`
/// returns: enabled | denied | unsupported | server_rejected | error.
library;

export 'web_push_stub.dart'
    if (dart.library.js_interop) 'web_push_web.dart';
