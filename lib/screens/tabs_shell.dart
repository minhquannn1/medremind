import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../store/app_state.dart';
import '../theme/tokens.dart';
import 'home_screen.dart';
import 'prescriptions_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

/// Bottom tab bar. Ported from `app/(tabs)/_layout.tsx`.
class TabsShell extends ConsumerWidget {
  const TabsShell({super.key, required this.index});

  final int index;

  static const _routes = ['/home', '/prescriptions', '/schedule', '/profile'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);

    final body = switch (index) {
      1 => const PrescriptionsScreen(),
      2 => const ScheduleScreen(),
      3 => const ProfileScreen(),
      _ => const HomeScreen(),
    };

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        onDestinationSelected: (i) {
          if (i != index) context.go(_routes[i]);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: AppColors.primary),
            label: t.t('tabs.home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.description_outlined),
            selectedIcon:
                const Icon(Icons.description, color: AppColors.primary),
            label: t.t('tabs.prescriptions'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.schedule_outlined),
            selectedIcon: const Icon(Icons.schedule, color: AppColors.primary),
            label: t.t('tabs.schedule'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: AppColors.primary),
            label: t.t('tabs.profile'),
          ),
        ],
      ),
    );
  }
}
