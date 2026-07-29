import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/app_state.dart';
import '../theme/tokens.dart';
import 'home_screen.dart';
import 'prescriptions_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

/// Bottom tab bar. Ported from `app/(tabs)/_layout.tsx`.
///
/// One route holds all four tabs in an IndexedStack: switching tabs swaps the
/// visible child instead of pushing a route, so the bar stays put and each tab
/// keeps its scroll position and already-loaded data. A route per tab would
/// rebuild the screen — and re-run its queries — on every tap.
class TabsShell extends ConsumerStatefulWidget {
  const TabsShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends ConsumerState<TabsShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

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
