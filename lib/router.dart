import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/tabs_shell.dart';
import 'store/app_state.dart';
import 'theme/tokens.dart';

/// Navigation. Ported from the expo-router file tree in `app/`:
/// `app/auth.tsx` → /auth, `app/(tabs)/index.tsx` → /home, and so on.
/// Bridges session changes to GoRouter. Kept in its own ChangeNotifierProvider
/// so it is watched (and therefore alive) for the app's lifetime — a listener
/// created inline inside the router provider can be dropped, which leaves a
/// signed-in user stranded on the login screen.
class RouterRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}

final routerRefreshProvider = ChangeNotifierProvider<RouterRefresh>((ref) {
  final refresh = RouterRefresh();
  ref.listen<AppState>(appStateProvider, (previous, next) {
    if (previous?.ready != next.ready ||
        previous?.authed != next.authed ||
        previous?.onboarded != next.onboarded) {
      refresh.bump();
    }
  });
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // read, not watch: watching would rebuild this provider on every session
    // change and invalidate the ref the redirect below is still using.
    refreshListenable: ref.read(routerRefreshProvider),
    redirect: (context, state) {
      final app = ref.read(appStateProvider);
      final loc = state.matchedLocation;

      // Hold on the splash until the stored session has been read, otherwise
      // a signed-in user is briefly bounced to the login screen.
      if (!app.ready) return loc == '/' ? null : '/';

      if (!app.authed) return loc == '/auth' ? null : '/auth';
      if (!app.onboarded) return loc == '/onboarding' ? null : '/onboarding';

      if (loc == '/' || loc == '/auth' || loc == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: '/home', builder: (_, _) => const TabsShell(index: 0)),
      GoRoute(
        path: '/prescriptions',
        builder: (_, _) => const TabsShell(index: 1),
      ),
      GoRoute(path: '/schedule', builder: (_, _) => const TabsShell(index: 2)),
      GoRoute(path: '/profile', builder: (_, _) => const TabsShell(index: 3)),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Icon(Icons.medical_services, size: 64, color: Colors.white),
      ),
    );
  }
}
