import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_text.dart';
import '../components/controls.dart';
import '../components/layout.dart';
import '../db/repositories/settings_repository.dart';
import '../features/links.dart';
import '../i18n/app_localizations.dart';
import '../store/app_state.dart';
import '../theme/tokens.dart';
import 'doctor_screen.dart';

/// Language, reminder preferences, account actions and legal links.
/// Ported from `app/settings.tsx`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _sound = true;
  bool _vibration = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsRepositoryProvider);
    final sound = await settings.getBool(SettingsKeys.reminderSound, true);
    final vibration =
        await settings.getBool(SettingsKeys.reminderVibration, true);
    if (!mounted) return;
    setState(() {
      _sound = sound;
      _vibration = vibration;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    await ref.read(settingsRepositoryProvider).set(key, '$value');
    final app = ref.read(appStateProvider);
    await ref
        .read(notificationSchedulerProvider)
        .applyReminderPrefs(app.activePatientId, app.t);
  }

  Future<void> _confirmDeleteAccount() async {
    final t = ref.read(translationsProvider);

    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('auth.deleteAccountConfirmTitle')),
        content: Text(t.t('auth.deleteAccountConfirmBody')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.t('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.t('auth.deleteAccount'),
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // Second confirmation: this is irreversible and wipes server data too.
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('auth.deleteAccountFinalTitle')),
        content: Text(t.t('auth.deleteAccountFinalBody')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.t('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.t('auth.deleteAccount'),
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    setState(() => _deleting = true);
    final ok = await ref.read(appStateProvider.notifier).deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);

    if (ok) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('auth.deleteAccountError'))),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final t = ref.read(translationsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('auth.logout')),
        content: Text(t.t('auth.logoutConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.t('auth.logout'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(appStateProvider.notifier).signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final app = ref.watch(appStateProvider);

    return AppScreen(
      children: [
        AppHeader(title: t.t('settings.title')),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.language, color: AppColors.primary, size: 20),
                const SizedBox(width: Spacing.sm),
                AppText(t.t('settings.language'),
                    variant: TextVariant.bodyStrong),
              ]),
              const SizedBox(height: Spacing.md),
              SegmentedControl<AppLanguage>(
                value: app.language,
                options: [
                  ChipOption(
                      value: AppLanguage.vi, label: t.t('settings.languageVi')),
                  ChipOption(
                      value: AppLanguage.en, label: t.t('settings.languageEn')),
                ],
                onChanged: (lang) =>
                    ref.read(appStateProvider.notifier).setLanguage(lang),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: Spacing.sm),
                AppText(t.t('settings.notifications'),
                    variant: TextVariant.bodyStrong),
              ]),
              const AppDivider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                value: _sound,
                title: AppText(t.t('settings.reminderSound')),
                onChanged: (v) {
                  setState(() => _sound = v);
                  _setPref(SettingsKeys.reminderSound, v);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                value: _vibration,
                title: AppText(t.t('settings.reminderVibration')),
                onChanged: (v) {
                  setState(() => _vibration = v);
                  _setPref(SettingsKeys.reminderVibration, v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.person_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: Spacing.sm),
                AppText(t.t('auth.account'), variant: TextVariant.bodyStrong),
              ]),
              if (app.account != null) ...[
                const SizedBox(height: Spacing.sm),
                AppText(app.account!.name),
                AppText(app.account!.email,
                    variant: TextVariant.caption,
                    color: TextColorKey.textFaint),
              ],
              const AppDivider(),
              AppButton(
                label: t.t('auth.logout'),
                variant: ButtonVariant.ghost,
                icon: Icons.logout,
                onPressed: _confirmLogout,
              ),
              const SizedBox(height: Spacing.sm),
              // App Store Guideline 5.1.1(v): account deletion must be
              // reachable from inside the app.
              AppButton(
                label: _deleting
                    ? t.t('common.loading')
                    : t.t('auth.deleteAccount'),
                variant: ButtonVariant.danger,
                icon: Icons.delete_outline,
                disabled: _deleting,
                onPressed: _confirmDeleteAccount,
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        AppCard(
          onPress: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DoctorScreen()),
          ),
          child: Row(children: [
            const Icon(Icons.medical_information_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: Spacing.md),
            Expanded(child: AppText(t.t('doctor.title'))),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ]),
        ),
        const SizedBox(height: Spacing.md),

        AppCard(
          onPress: () => openExternalUrl(privacyPolicyUrl),
          child: Row(children: [
            const Icon(Icons.shield_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: Spacing.md),
            Expanded(child: AppText(t.t('settings.privacyPolicy'))),
            const Icon(Icons.open_in_new,
                size: 18, color: AppColors.textMuted),
          ]),
        ),
        const SizedBox(height: Spacing.md),
        AppCard(
          onPress: () => openExternalUrl(supportUrl),
          child: Row(children: [
            const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: Spacing.md),
            Expanded(child: AppText(t.t('settings.support'))),
            const Icon(Icons.open_in_new,
                size: 18, color: AppColors.textMuted),
          ]),
        ),

        const SizedBox(height: Spacing.xxl),
        AppText('MedRemind · v1.0.0',
            variant: TextVariant.caption,
            color: TextColorKey.textFaint,
            center: true),
      ],
    );
  }
}
