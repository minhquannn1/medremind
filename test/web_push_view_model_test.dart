import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:medremind/data/services/web_push/push_status_api.dart';
import 'package:medremind/ui/features/settings/view_models/web_push_view_model.dart';

/// The self-serve push check in Settings. Users granted permission during a
/// broken flow and had no way to see that no subscription was ever stored —
/// these pin the states that screen can report.
void main() {
  PushStatusApi apiWith(Map<String, Object?> statusBody,
          {Map<String, Object?>? testBody}) =>
      PushStatusApi(
        client: MockClient((req) async {
          final body = req.url.path.endsWith('/push/test')
              ? (testBody ?? const {'ok': true, 'delivered': 1})
              : statusBody;
          return http.Response(
              '{${body.entries.map((e) => '"${e.key}":${e.value is String ? '"${e.value}"' : e.value}').join(',')}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

  WebPushViewModel build(PushStatusApi api,
          {String enableResult = 'enabled'}) =>
      WebPushViewModel(
        readToken: () async => 'tk',
        lang: 'vi',
        api: api,
        enabler: (token, lang, {bool onlyIfGranted = false}) async =>
            enableResult,
      );

  test('refresh reports how many browsers are subscribed', () async {
    final vm = build(apiWith(const {'ok': true, 'count': 2}));
    await vm.refresh();
    expect(vm.count, 2);
  });

  test('enabling here subscribes and rereads the count', () async {
    final vm = build(apiWith(const {'ok': true, 'count': 1}));
    await vm.enableHere();
    expect(vm.messageKey, 'settings.webPushEnabled');
    expect(vm.count, 1);
  });

  test('a blocked permission tells the user how to unblock, not "error"',
      () async {
    final vm = build(apiWith(const {'ok': true, 'count': 0}),
        enableResult: 'denied');
    await vm.enableHere();
    expect(vm.messageKey, 'settings.webPushDenied');
  });

  test('an unsupported browser points at Add to Home Screen', () async {
    final vm = build(apiWith(const {'ok': true, 'count': 0}),
        enableResult: 'unsupported');
    await vm.enableHere();
    expect(vm.messageKey, 'settings.webPushUnsupported');
  });

  test('a test push that reached a device says so', () async {
    final vm = build(apiWith(const {'ok': true, 'count': 1}));
    await vm.sendTest();
    expect(vm.messageKey, 'settings.webPushTestSent');
  });

  test('a test push with nothing subscribed says that instead', () async {
    final vm = build(apiWith(const {'ok': true, 'count': 0},
        testBody: const {'ok': true, 'delivered': 0}));
    await vm.sendTest();
    expect(vm.messageKey, 'settings.webPushNoDevices');
  });

  test('without a session every action is a quiet no-op', () async {
    final vm = WebPushViewModel(
      readToken: () async => null,
      lang: 'vi',
      api: apiWith(const {'ok': true, 'count': 5}),
      enabler: (t, l, {bool onlyIfGranted = false}) async => 'enabled',
    );
    await vm.refresh();
    await vm.sendTest();
    expect(vm.count, isNull);
    expect(vm.messageKey, isNull);
  });
}
