import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'router.dart';
import 'store/app_state.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Create the schema before the first screen can query it.
  await AppDatabase.instance.db;
  runApp(const ProviderScope(child: MedRemindApp()));
}

class MedRemindApp extends ConsumerStatefulWidget {
  const MedRemindApp({super.key});

  @override
  ConsumerState<MedRemindApp> createState() => _MedRemindAppState();
}

class _MedRemindAppState extends ConsumerState<MedRemindApp> {
  @override
  void initState() {
    super.initState();
    // Restore the session, then bring notifications up with the right language.
    Future.microtask(() async {
      await ref.read(appStateProvider.notifier).load();
      if (!mounted) return;
      final t = ref.read(translationsProvider);
      try {
        await ref.read(notificationSchedulerProvider).initialize(t);
      } catch (_) {
        // A notification-init failure must never block app start; the user is
        // warned in context when a reminder actually needs permission.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the session listener stays alive and the router keeps
    // reacting to sign-in / sign-out.
    ref.watch(routerRefreshProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MedRemind',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: _theme,
      locale: Locale(ref.watch(appStateProvider).language.name),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

final ThemeData _theme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.surface,
  ),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
);
