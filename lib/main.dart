import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/data/services/database.dart';
import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/data/services/notification_service.dart';
import 'package:medremind/router.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Create the schema before the first screen can query it.
  await AppDatabase.instance.db;
  runApp(const ProviderScope(child: MedolyApp()));
}

class MedolyApp extends ConsumerStatefulWidget {
  const MedolyApp({super.key});

  @override
  ConsumerState<MedolyApp> createState() => _MedolyAppState();
}

class _MedolyAppState extends ConsumerState<MedolyApp> {
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

        // Only for someone who has already been through the walkthrough;
        // first-run users are asked when it ends, once they know why.
        final settings = ref.read(settingsRepositoryProvider);
        if (await settings.getBool(SettingsKeys.seenWelcome, false)) {
          await askForNotificationsOnce(scheduler, settings);
        }

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
      // A profile, not an account: reminders fire for signed-out users too.
      if (!ref.read(appStateProvider).onboarded) return;
      ref
          .read(routerProvider)
          .push(
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
      title: 'Medoly',
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
