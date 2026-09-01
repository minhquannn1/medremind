import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/data/services/notification_service.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/features/home/views/home_screen.dart';
import 'package:medremind/ui/features/prescriptions/views/prescriptions_screen.dart';
import 'package:medremind/ui/features/profile/views/profile_screen.dart';
import 'package:medremind/ui/features/schedule/views/schedule_screen.dart';
import 'package:medremind/ui/features/welcome/view_models/welcome_view_model.dart';
import 'package:medremind/ui/features/welcome/views/welcome_carousel.dart';

/// Bottom tab bar. Ported from `app/(tabs)/_layout.tsx`.
///
/// One route holds all four tabs in an IndexedStack: switching tabs swaps the
/// visible child instead of pushing a route, so the bar stays put and each tab
/// keeps its scroll position and already-loaded data. A route per tab would
/// rebuild the screen — and re-run its queries — on every tap.
class TabsShell extends ConsumerStatefulWidget {
  const TabsShell({super.key, this.initialIndex = 0, this.welcome});

  final int initialIndex;

  /// The first-run walkthrough. Injected so a widget test can supply one that
  /// is already settled instead of reaching for the database on build.
  final WelcomeViewModel? welcome;

  @override
  ConsumerState<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends ConsumerState<TabsShell> {
  late int _index = widget.initialIndex;

  late final WelcomeViewModel _welcome = widget.welcome ?? WelcomeViewModel();

  @override
  void initState() {
    super.initState();
    // Only load one we own; an injected view model belongs to its caller.
    if (widget.welcome == null) {
      _welcome.onFinished = _askForNotifications;
      _welcome.load();
    }
  }

  @override
  void dispose() {
    if (widget.welcome == null) _welcome.dispose();
    super.dispose();
  }

  /// The walkthrough has just explained what the reminders are for, which is
  /// the moment the permission sheet makes sense.
  Future<void> _askForNotifications() async {
    await askForNotificationsOnce(
      ref.read(notificationSchedulerProvider),
      ref.read(settingsRepositoryProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    // The walkthrough sits on top of a shell that is already built and usable,
    // so dismissing it reveals the app rather than loading it.
    return ListenableBuilder(
      listenable: _welcome,
      builder: (context, shell) => Stack(
        children: [
          shell!,
          if (_welcome.visible) WelcomeCarousel(vm: _welcome, t: t),
        ],
      ),
      child: _shell(t),
    );
  }

  Widget _shell(Translations t) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          PrescriptionsScreen(),
          ScheduleScreen(),
          ProfileScreen(),
        ],
      ),
      // Colours, height, indicator and label styles all come from
      // navigationBarTheme so the bar stays token-driven.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i != _index) setState(() => _index = i);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t.t('tabs.home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.description_outlined),
            selectedIcon: const Icon(Icons.description),
            label: t.t('tabs.prescriptions'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.schedule_outlined),
            selectedIcon: const Icon(Icons.schedule),
            label: t.t('tabs.schedule'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: t.t('tabs.profile'),
          ),
        ],
      ),
    );
  }
}
