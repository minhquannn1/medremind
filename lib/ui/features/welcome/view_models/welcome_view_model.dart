import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/settings_repository.dart';

/// One page of the first-run walkthrough.
class WelcomePage {
  const WelcomePage({
    required this.titleKey,
    required this.bodyKey,
    this.footnoteKey,
  });

  final String titleKey;
  final String bodyKey;

  /// Smaller print under the body — used for the medical disclaimer.
  final String? footnoteKey;
}

/// The walkthrough shown once, on the first launch after install.
///
/// It explains the app and carries the medical disclaimer (App Review
/// guideline 1.4.1). It asks for nothing: there is no field on any page and
/// every page can be skipped, so it stays clear of Guideline 5.1.1(v), which
/// is what got builds 3 and 4 rejected.
class WelcomeViewModel extends ChangeNotifier {
  WelcomeViewModel({this.settings = const SettingsRepository()});

  final SettingsRepository settings;

  static const List<WelcomePage> pages = [
    WelcomePage(
      titleKey: 'welcome.introTitle',
      bodyKey: 'welcome.introBody',
      footnoteKey: 'welcome.disclaimer',
    ),
    WelcomePage(
      titleKey: 'welcome.addTitle',
      bodyKey: 'welcome.addBody',
    ),
    WelcomePage(
      titleKey: 'welcome.remindTitle',
      bodyKey: 'welcome.remindBody',
    ),
    WelcomePage(
      titleKey: 'welcome.trackTitle',
      bodyKey: 'welcome.trackBody',
    ),
  ];

  /// Run once the walkthrough ends, however it ends. Used to ask for
  /// notification permission at the point the user knows what it is for.
  Future<void> Function()? onFinished;

  bool _visible = false;
  bool get visible => _visible;

  int _index = 0;
  int get index => _index;

  WelcomePage get page => pages[_index];
  bool get isLast => _index == pages.length - 1;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _visible = !await settings.getBool(SettingsKeys.seenWelcome, false);
    _notify();
  }

  void goTo(int index) {
    if (index < 0 || index >= pages.length || index == _index) return;
    _index = index;
    _notify();
  }

  /// Advances, or finishes on the last page.
  Future<void> next() async {
    if (isLast) return finish();
    _index++;
    _notify();
  }

  /// Ends the walkthrough for good. Skipping and finishing are the same thing:
  /// nothing here is required, so neither needs to be nagged about again.
  Future<void> finish() async {
    _visible = false;
    _notify();
    await settings.set(SettingsKeys.seenWelcome, 'true');
    await onFinished?.call();
  }
}
