import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/ui/features/welcome/view_models/welcome_view_model.dart';

/// The first-run walkthrough. It explains the app and carries the medical
/// disclaimer, and must never behave like a step the user has to complete —
/// that distinction is what App Review rejected builds 3 and 4 over.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.close();
    await AppDatabase.instance.openInMemory();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  const settings = SettingsRepository();

  test('shows on the first launch and never again', () async {
    final first = WelcomeViewModel();
    await first.load();
    expect(first.visible, isTrue);

    await first.finish();
    expect(first.visible, isFalse);

    final second = WelcomeViewModel();
    await second.load();
    expect(second.visible, isFalse);
  });

  test('skipping counts as done — nothing here is required', () async {
    final vm = WelcomeViewModel();
    await vm.load();

    await vm.finish();

    expect(await settings.getBool(SettingsKeys.seenWelcome, false), isTrue);
  });

  test('next walks the pages and the last one ends the walkthrough', () async {
    final vm = WelcomeViewModel();
    await vm.load();

    for (var i = 0; i < WelcomeViewModel.pages.length - 1; i++) {
      expect(vm.index, i);
      expect(vm.isLast, isFalse);
      await vm.next();
    }

    expect(vm.isLast, isTrue);
    await vm.next();
    expect(vm.visible, isFalse);
  });

  test('the first page carries the medical disclaimer', () async {
    // Guideline 1.4.1 — it has to be put in front of the user, and this is
    // the only screen that runs before they can reach anything else.
    expect(WelcomeViewModel.pages.first.footnoteKey, 'welcome.disclaimer');
  });

  test('finishing asks for notification permission, once it makes sense',
      () async {
    // Not on launch: the sheet lands after the walkthrough has explained what
    // the reminders are for, which is when people say yes.
    var asked = 0;
    final vm = WelcomeViewModel()..onFinished = () async => asked++;
    await vm.load();

    await vm.finish();

    expect(asked, 1);
  });

  test('goTo ignores an index outside the deck', () async {
    final vm = WelcomeViewModel();
    vm.goTo(99);
    vm.goTo(-1);
    expect(vm.index, 0);
  });
}
