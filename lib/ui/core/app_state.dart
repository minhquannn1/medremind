import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/data/repositories/backup_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/data/services/patient_auth_service.dart';
import 'package:medremind/data/services/notification_service.dart';
import 'package:medremind/data/services/backup_sync_service.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';

/// Session + app-wide state. Ported from `src/store/appStore.ts` (zustand →
/// Riverpod StateNotifier).

class AppState {
  final bool ready;
  final bool authed;
  final AuthAccount? account;
  final bool onboarded;
  final int? activePatientId;
  final AppLanguage language;

  const AppState({
    this.ready = false,
    this.authed = false,
    this.account,
    this.onboarded = false,
    this.activePatientId,
    this.language = AppLanguage.vi,
  });

  AppState copyWith({
    bool? ready,
    bool? authed,
    AuthAccount? account,
    bool clearAccount = false,
    bool? onboarded,
    int? activePatientId,
    bool clearPatient = false,
    AppLanguage? language,
  }) =>
      AppState(
        ready: ready ?? this.ready,
        authed: authed ?? this.authed,
        account: clearAccount ? null : (account ?? this.account),
        onboarded: onboarded ?? this.onboarded,
        activePatientId:
            clearPatient ? null : (activePatientId ?? this.activePatientId),
        language: language ?? this.language,
      );

  Translations get t => Translations(language);
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier({
    required this.settings,
    required this.patients,
    required this.backups,
    required this.auth,
    required this.backupSync,
    required this.notifications,
  }) : super(const AppState());

  final SettingsRepository settings;
  final PatientsRepository patients;
  final BackupRepository backups;
  final PatientAuthApi auth;
  final BackupSyncApi backupSync;
  final NotificationScheduler notifications;

  Future<void> _persistSession(String token, AuthAccount account) async {
    await settings.set(SettingsKeys.authToken, token);
    await settings.set(SettingsKeys.accountUserId, '${account.userId}');
    await settings.set(SettingsKeys.accountEmail, account.email);
    await settings.set(SettingsKeys.accountName, account.name);
  }

  Future<void> _clearSession() async {
    await settings.set(SettingsKeys.authToken, '');
    await settings.set(SettingsKeys.accountUserId, '');
    await settings.set(SettingsKeys.accountEmail, '');
    await settings.set(SettingsKeys.accountName, '');
  }

  /// Restores the stored session on launch.
  Future<void> load() async {
    final storedLang = await settings.get(SettingsKeys.language);
    final language = storedLang == null || storedLang.isEmpty
        ? detectDeviceLanguage(_deviceLocale())
        : languageFromCode(storedLang);

    final token = await settings.get(SettingsKeys.authToken);
    if (token == null || token.isEmpty) {
      state = AppState(ready: true, language: language);
      return;
    }

    final userId = int.tryParse(
            await settings.get(SettingsKeys.accountUserId) ?? '') ??
        0;
    final account = AuthAccount(
      userId: userId,
      email: await settings.get(SettingsKeys.accountEmail) ?? '',
      name: await settings.get(SettingsKeys.accountName) ?? '',
    );
    final patient = await patients.getPatientByAccount(userId);

    state = AppState(
      ready: true,
      authed: true,
      account: account,
      onboarded: patient != null,
      activePatientId: patient?.id,
      language: language,
    );
  }

  Locale _deviceLocale() {
    final locales = PlatformDispatcher.instance.locales;
    return locales.isEmpty ? const Locale('vi') : locales.first;
  }

  Future<AuthErrorCode?> signIn(String email, String password) async {
    final res = await auth.login(email, password);
    if (!res.ok) return res.error;

    await _persistSession(res.token!, res.account!);
    var patient = await patients.getPatientByAccount(res.account!.userId);

    if (patient == null) {
      // Fresh device: restore the account's cloud backup if one exists.
      final backup = await backupSync.fetchServerBackup(res.token!);
      if (backup != null) {
        try {
          final patientId = await backups.importPatientData(
            backup,
            res.account!.userId,
            res.account!.email,
          );
          // A restored profile has medications but no scheduled alerts, and
          // syncReminders no-ops without permission — ask here or the user
          // gets their data back with every reminder missing.
          await notifications.requestPermission();
          await notifications.syncReminders(patientId, state.t);
          patient = await patients.getPatientByAccount(res.account!.userId);
        } catch (_) {
          // A failed restore must not block sign-in; the user can start fresh.
          patient = await patients.getPatientByAccount(res.account!.userId);
        }
      }
    }

    state = state.copyWith(
      authed: true,
      account: res.account,
      onboarded: patient != null,
      activePatientId: patient?.id,
      clearPatient: patient == null,
    );
    return null;
  }

  Future<AuthErrorCode?> signUp(
      String email, String password, String name) async {
    final res = await auth.register(email, password, name);
    if (!res.ok) return res.error;

    await _persistSession(res.token!, res.account!);
    // Let this new account adopt any pre-existing on-device profile.
    await patients.claimOrphanPatient(res.account!.userId, res.account!.email);
    final patient = await patients.getPatientByAccount(res.account!.userId);

    state = state.copyWith(
      authed: true,
      account: res.account,
      onboarded: patient != null,
      activePatientId: patient?.id,
      clearPatient: patient == null,
    );
    return null;
  }

  /// Clears the session only — on-device data stays, tied to the account, and
  /// is restored on the next sign-in.
  Future<void> signOut() async {
    await _clearSession();
    state = state.copyWith(
      authed: false,
      clearAccount: true,
      onboarded: false,
      clearPatient: true,
    );
  }

  /// Deletes the account and every trace of it, locally and on the server.
  /// Required by App Store Guideline 5.1.1(v).
  Future<bool> deleteAccount() async {
    final token = await settings.get(SettingsKeys.authToken);
    if (token == null || token.isEmpty) return false;

    final pairCode = await settings.get(SettingsKeys.doctorPairCode);
    final deleted = await auth.deleteAccount(
      token,
      (pairCode == null || pairCode.isEmpty) ? null : pairCode,
    );
    if (!deleted) return false;

    final userId =
        int.tryParse(await settings.get(SettingsKeys.accountUserId) ?? '') ?? 0;
    final patient = await patients.getPatientByAccount(userId);
    if (patient != null) {
      await backups.deleteLocalPatientData(patient.id);
      try {
        await notifications.cancelAll();
      } catch (_) {
        // Nothing references the data anymore; cleanup is best-effort.
      }
    }

    await _clearSession();
    state = state.copyWith(
      authed: false,
      clearAccount: true,
      onboarded: false,
      clearPatient: true,
    );
    return true;
  }

  Future<void> completeOnboarding(int patientId) async {
    state = state.copyWith(onboarded: true, activePatientId: patientId);
  }

  Future<void> setLanguage(AppLanguage lang) async {
    await settings.set(SettingsKeys.language, languageCode(lang));
    state = state.copyWith(language: lang);
  }

  Future<void> setActivePatient(int id) async {
    state = state.copyWith(activePatientId: id);
  }
}

// ---- Providers --------------------------------------------------------------

final settingsRepositoryProvider =
    Provider<SettingsRepository>((_) => const SettingsRepository());
final patientsRepositoryProvider =
    Provider<PatientsRepository>((_) => const PatientsRepository());
final backupRepositoryProvider =
    Provider<BackupRepository>((_) => const BackupRepository());
final patientAuthProvider =
    Provider<PatientAuthApi>((_) => const PatientAuthApi());

final backupSyncProvider = Provider<BackupSyncApi>((ref) {
  final api = BackupSyncApi();
  ref.onDispose(api.dispose);
  return api;
});

final notificationSchedulerProvider =
    Provider<NotificationScheduler>((_) => NotificationScheduler());

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier(
    settings: ref.watch(settingsRepositoryProvider),
    patients: ref.watch(patientsRepositoryProvider),
    backups: ref.watch(backupRepositoryProvider),
    auth: ref.watch(patientAuthProvider),
    backupSync: ref.watch(backupSyncProvider),
    notifications: ref.watch(notificationSchedulerProvider),
  );
});

/// Bumped whenever dose data changes somewhere other than the screen showing
/// it. The home tab stays alive in the tab stack, so without this its figures
/// would still show the numbers from before a dose was confirmed.
final doseRevisionProvider = StateProvider<int>((_) => 0);

/// Convenience for widgets: the translator for the active language.
final translationsProvider = Provider<Translations>(
  (ref) => Translations(ref.watch(appStateProvider).language),
);
