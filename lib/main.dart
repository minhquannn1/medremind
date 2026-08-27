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

        await _askForNotificationsOnce(scheduler);

        // A tap that launched the app from closed does not fire the callback.
        final launched = await scheduler.launchPayload();
        if (launched != null) _openDose(launched);
      } catch (_) {
        // A notification-init failure must never block app start; the user is
        // warned in context when a reminder actually needs permission.
      }
    });
  }

  /// Asks for notification permission once the user has a profile. Reminders
  /// are the whole point of the app, and the old flow only asked when a
  /// prescription was saved — so anyone who restored a backup, or simply
  /// browsed first, had medications and no alerts without being told.
  ///
  /// Keyed on having a profile rather than on being signed in: most users now
  /// never create an account, and they need reminders just as much.
  ///
  /// Asked once and remembered: iOS only ever shows the system prompt once
  /// anyway, and re-asking a user who declined just runs a no-op.
  Future<void> _askForNotificationsOnce(NotificationScheduler scheduler) async {
    if (!ref.read(appStateProvider).onboarded) return;

    final settings = ref.read(settingsRepositoryProvider);
    if (await settings.getBool(SettingsKeys.askedNotifications, false)) return;

    await scheduler.requestPermission();
    await settings.set(SettingsKeys.askedNotifications, 'true');
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
