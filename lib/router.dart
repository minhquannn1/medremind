import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:medremind/ui/features/auth/views/auth_screen.dart';
import 'package:medremind/ui/features/dose_confirm/views/dose_confirm_screen.dart';
import 'package:medremind/ui/core/tabs_shell.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

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
        previous?.activePatientId != next.activePatientId) {
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

      // Signing in is optional. Reminders, prescriptions and history all live
      // on the device, so requiring an account to reach them fails App Store
      // Guideline 5.1.1(v). An account only adds cloud backup, and is asked
      // for at the point it is actually used.
      if (loc == '/auth') return app.authed ? '/home' : null;

      if (loc == '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      // One route for all four tabs: TabsShell owns the selected index, so a
      // tab tap never pushes a route and never rebuilds the other tabs.
      GoRoute(path: '/home', builder: (_, _) => const TabsShell()),
      GoRoute(
        path: '/dose',
        builder: (_, state) => DoseConfirmScreen(
          medicationId:
              int.tryParse(state.uri.queryParameters['med'] ?? '') ?? 0,
          time: state.uri.queryParameters['time'] ?? '',
        ),
      ),
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
