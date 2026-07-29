import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'features/notifications/scheduler.dart';
import 'router.dart';
import 'store/app_state.dart';
import 'theme/app_theme.dart';

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
        final scheduler = ref.read(notificationSchedulerProvider);
        scheduler.onDoseTapped = _openDose;
        await scheduler.initialize(t);

        // A tap that launched the app from closed does not fire the callback.
        final launched = await scheduler.launchPayload();
        if (launched != null) _openDose(launched);
      } catch (_) {
        // A notification-init failure must never block app start; the user is
        // warned in context when a reminder actually needs permission.
      }
    });
  }

  /// Opens the confirmation screen for a tapped reminder. Deferred until the
  /// session has loaded, or the redirect would bounce it back to the splash.
  void _openDose(DoseTapPayload payload) {
    Future.microtask(() {
      if (!mounted) return;
      if (!ref.read(appStateProvider).authed) return;
      ref.read(routerProvider).push(
            '/dose?med=${payload.medicationId}'
            '&time=${Uri.encodeComponent(payload.time)}',
          );
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
      theme: AppTheme.light,
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
