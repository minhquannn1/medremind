import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/features/settings/view_models/settings_view_model.dart';
import 'package:medremind/data/services/links.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/features/doctor/views/doctor_screen.dart';

/// Language, reminder preferences, account actions and legal links.
/// Ported from `app/settings.tsx`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final SettingsViewModel _vm = SettingsViewModel(
    applyReminderPrefs: () {
      final app = ref.read(appStateProvider);
      return ref
          .read(notificationSchedulerProvider)
          .applyReminderPrefs(app.activePatientId, app.t);
    },
    deleteAccount: ref.read(appStateProvider.notifier).deleteAccount,
    signOut: ref.read(appStateProvider.notifier).signOut,
  );

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
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

    final ok = await _vm.confirmDelete();
    if (!mounted) return;

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
    await _vm.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final app = ref.watch(appStateProvider);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _build(t, app),
    );
  }

  Widget _build(Translations t, AppState app) {
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
              // Plain rows rather than SwitchListTile: the tile wants a Material
              // ancestor for its ink, which the card's plain container does not
              // provide, and Flutter warns about it on every build.
              _ToggleRow(
                label: t.t('settings.reminderSound'),
                value: _vm.sound,
                onChanged: _vm.setSound,
              ),
              _ToggleRow(
                label: t.t('settings.reminderVibration'),
                value: _vm.vibration,
                onChanged: _vm.setVibration,
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
                label: _vm.deleting
                    ? t.t('common.loading')
                    : t.t('auth.deleteAccount'),
                variant: ButtonVariant.danger,
                icon: Icons.delete_outline,
                disabled: _vm.deleting,
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
          onPress: () => openExternalUrl(termsUrl),
          child: Row(children: [
            const Icon(Icons.gavel_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: Spacing.md),
            Expanded(child: AppText(t.t('settings.terms'))),
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: AppText(label)),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
