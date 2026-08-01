import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_input.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/features/doctor/view_models/doctor_view_model.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

/// Pair with a doctor and push adherence snapshots.
/// Ported from `app/doctor.tsx`.
class DoctorScreen extends ConsumerStatefulWidget {
  const DoctorScreen({super.key});

  @override
  ConsumerState<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends ConsumerState<DoctorScreen> {
  late final DoctorViewModel _vm = DoctorViewModel(
    patientId: ref.read(appStateProvider).activePatientId,
  );
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _code.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _connect() => _vm.connect(_code.text);

  Future<void> _syncNow() async {
    final t = ref.read(translationsProvider);
    final ok = await _vm.syncNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? t.t('doctor.syncDone') : t.t('doctor.networkError')),
    ));
  }

  Future<void> _disconnect() async {
    final t = ref.read(translationsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('doctor.disconnect')),
        content: Text(t.t('doctor.disconnectConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.t('doctor.disconnect'))),
        ],
      ),
    );
    if (ok != true) return;
    await _vm.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _build(t),
    );
  }

  Widget _build(Translations t) {
    final link = _vm.link;

    return AppScreen(
      children: [
        AppHeader(title: t.t('doctor.title')),
        AppText(t.t('doctor.subtitle'), color: TextColorKey.textMuted),
        const SizedBox(height: Spacing.xl),

        if (link == null) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(t.t('doctor.enterCodeTitle'),
                    variant: TextVariant.bodyStrong),
                const SizedBox(height: Spacing.xs),
                AppText(t.t('doctor.enterCodeHint'),
                    variant: TextVariant.caption,
                    color: TextColorKey.textFaint),
                const SizedBox(height: Spacing.md),
                AppInput(
                  controller: _code,
                  placeholder: 'MED-XXXXXX',
                  icon: Icons.qr_code,
                  autocorrect: false,
                  error: _vm.errorKey == null ? null : t.t(_vm.errorKey!),
                ),
                AppButton(
                  label: t.t('doctor.connect'),
                  icon: Icons.link,
                  loading: _vm.busy,
                  onPressed: _connect,
                ),
              ],
            ),
          ),
        ] else ...[
          AppCard(
            tone: CardTone.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(t.t('doctor.connectedTo'),
                    variant: TextVariant.caption,
                    color: TextColorKey.primary),
                AppText(
                  link.doctorName.isEmpty
                      ? t.t('doctor.yourDoctor')
                      : link.doctorName,
                  variant: TextVariant.subheading,
                ),
                const SizedBox(height: Spacing.xs),
                AppText('${t.t('doctor.code')}: ${link.pairCode}',
                    variant: TextVariant.caption,
                    color: TextColorKey.textMuted),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          AppButton(
            label: t.t('doctor.syncNow'),
            icon: Icons.sync,
            loading: _vm.busy,
            onPressed: _syncNow,
          ),
          const SizedBox(height: Spacing.md),
          AppButton(
            label: t.t('doctor.disconnect'),
            variant: ButtonVariant.danger,
            icon: Icons.link_off,
            onPressed: _disconnect,
          ),
        ],

        const SizedBox(height: Spacing.xl),
        AppText(t.t('doctor.privacyNote'),
            variant: TextVariant.caption, color: TextColorKey.textFaint),
      ],
    );
  }
}
