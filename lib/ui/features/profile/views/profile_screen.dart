import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_input.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/fields.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/features/profile/view_models/profile_view_model.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/features/history/views/history_screen.dart';
import 'package:medremind/ui/features/settings/views/settings_screen.dart';

/// Patient profile: identity, metrics, conditions, allergies.
/// Ported from `app/(tabs)/profile.tsx`.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ProfileViewModel _vm = ProfileViewModel(
    patientId: ref.read(appStateProvider).activePatientId,
    backupSync: ref.read(backupSyncProvider),
  );

  final _height = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _beginEdit() {
    _vm.startEditing();
    _height.text = _vm.heightDraft;
    _weight.text = _vm.weightDraft;
  }

  Future<void> _save() async {
    _vm.heightDraft = _height.text;
    _vm.weightDraft = _weight.text;
    await _vm.saveMetrics();
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
    if (_vm.loading) {
      return const AppScreen(
          children: [Center(child: CircularProgressIndicator())]);
    }

    final p = _vm.patient;
    if (p == null) {
      return AppScreen(children: [
        AppText(t.t('profile.title'), variant: TextVariant.title),
      ]);
    }

    return AppScreen(
      onRefresh: _vm.load,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(t.t('profile.title'), variant: TextVariant.title),
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: AppColors.textMuted),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),

        AppCard(
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: AppText(_vm.initials,
                    variant: TextVariant.heading,
                    color: TextColorKey.textInverse),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(p.fullName, variant: TextVariant.subheading),
                    AppText(
                      [
                        if (_vm.age != null)
                          '${_vm.age} ${t.t('profile.age').toLowerCase()}',
                        if (p.gender != null)
                          t.t('profile.genders.${p.gender}'),
                      ].join(' · '),
                      color: TextColorKey.textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        SectionHeader(
          title: t.t('profile.anthropometry'),
          actionLabel: _vm.editing ? t.t('common.save') : t.t('common.edit'),
          onAction: () {
            if (_vm.editing) {
              _save();
            } else {
              _beginEdit();
            }
          },
        ),
        if (_vm.editing)
          AppCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppInput(
                        controller: _height,
                        label: t.t('profile.height'),
                        keyboardType: TextInputType.number,
                        suffix: 'cm',
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: AppInput(
                        controller: _weight,
                        label: t.t('profile.weight'),
                        keyboardType: TextInputType.number,
                        suffix: 'kg',
                      ),
                    ),
                  ],
                ),
                DateField(
                  label: t.t('profile.dob'),
                  value: _vm.dobDraft,
                  maximumDate: DateTime.now(),
                  onChanged: _vm.setDob,
                ),
                ChipSelect<String>(
                  label: t.t('profile.gender'),
                  value: _vm.genderDraft,
                  options: [
                    ChipOption(
                        value: 'male', label: t.t('profile.genders.male')),
                    ChipOption(
                        value: 'female', label: t.t('profile.genders.female')),
                    ChipOption(
                        value: 'other', label: t.t('profile.genders.other')),
                  ],
                  onChanged: _vm.setGender,
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              _Metric(
                  label: t.t('profile.height'),
                  value: p.heightCm?.toStringAsFixed(0) ?? '—',
                  unit: 'cm'),
              const SizedBox(width: Spacing.md),
              _Metric(
                  label: t.t('profile.weight'),
                  value: p.weightKg?.toStringAsFixed(0) ?? '—',
                  unit: 'kg'),
              const SizedBox(width: Spacing.md),
              _Metric(
                  label: t.t('profile.bmi'),
                  value: _vm.bmi?.toStringAsFixed(1) ?? '—',
                  unit: ''),
            ],
          ),
        const SizedBox(height: Spacing.lg),

        SectionHeader(title: t.t('profile.medicalHistory')),
        if (_vm.conditions.isEmpty)
          AppText(t.t('common.none'), color: TextColorKey.textFaint)
        else
          ..._vm.conditions.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: AppCard(
                  child: Row(children: [
                    const Icon(Icons.monitor_heart_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: Spacing.md),
                    Expanded(child: AppText(c.name)),
                  ]),
                ),
              )),
        const SizedBox(height: Spacing.lg),

        SectionHeader(title: t.t('profile.history')),
        AppCard(
          onPress: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
          child: Row(children: [
            const Icon(Icons.history, color: AppColors.primary, size: 20),
            const SizedBox(width: Spacing.md),
            Expanded(child: AppText(t.t('history.open'))),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ]),
        ),
        const SizedBox(height: Spacing.lg),

        SectionHeader(title: t.t('profile.allergies')),
        if (_vm.allergies.isEmpty)
          AppText(t.t('common.none'), color: TextColorKey.textFaint)
        else
          ..._vm.allergies.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: AppCard(
                  child: Row(children: [
                    const Icon(Icons.warning_amber_outlined,
                        color: AppColors.danger, size: 20),
                    const SizedBox(width: Spacing.md),
                    Expanded(child: AppText(a.substance)),
                    if (a.severity != null)
                      AppText(t.t('profile.severities.${a.severity}'),
                          variant: TextVariant.caption,
                          color: TextColorKey.textMuted),
                  ]),
                ),
              )),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(label,
                variant: TextVariant.caption, color: TextColorKey.textMuted),
            const SizedBox(height: Spacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AppText(value,
                    variant: TextVariant.heading, color: TextColorKey.primary),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  AppText(unit,
                      variant: TextVariant.caption,
                      color: TextColorKey.textFaint),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
