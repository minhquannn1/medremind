import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_input.dart';
import '../components/app_text.dart';
import '../components/layout.dart';
import '../features/sync/doctor_sync.dart';
import '../store/app_state.dart';
import '../theme/tokens.dart';

/// Pair with a doctor and push adherence snapshots.
/// Ported from `app/doctor.tsx`.
class DoctorScreen extends ConsumerStatefulWidget {
  const DoctorScreen({super.key});

  @override
  ConsumerState<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends ConsumerState<DoctorScreen> {
  static const _api = DoctorSyncApi();

  final _code = TextEditingController();
  DoctorLink? _link;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final link = await _api.getDoctorLink();
    if (mounted) setState(() => _link = link);
  }

  Future<void> _connect() async {
    final t = ref.read(translationsProvider);
    if (_code.text.trim().isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.pairWithDoctor(_code.text);
    if (!mounted) return;

    if (!res.ok) {
      setState(() {
        _busy = false;
        _error = res.error == PairError.invalidCode
            ? t.t('doctor.invalidCode')
            : t.t('doctor.networkError');
      });
      return;
    }

    // Push straight away so the doctor sees data instead of an empty profile.
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId != null) await _api.syncToDoctor(patientId);

    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _syncNow() async {
    final t = ref.read(translationsProvider);
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId == null) return;

    setState(() => _busy = true);
    final ok = await _api.syncToDoctor(patientId);
    if (!mounted) return;
    setState(() => _busy = false);
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
    await _api.unlinkDoctor();
    if (mounted) setState(() => _link = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final link = _link;

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
                  error: _error,
                ),
                AppButton(
                  label: t.t('doctor.connect'),
                  icon: Icons.link,
                  loading: _busy,
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
            loading: _busy,
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
