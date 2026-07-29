import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_card.dart';
import '../components/app_input.dart';
import '../components/app_text.dart';
import '../components/controls.dart';
import '../components/fields.dart';
import '../components/layout.dart';
import '../db/models.dart';
import '../db/repositories/patients_repository.dart';
import '../lib_date.dart';
import '../store/app_state.dart';
import '../theme/tokens.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Patient profile: identity, metrics, conditions, allergies.
/// Ported from `app/(tabs)/profile.tsx`.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _repo = PatientsRepository();

  Patient? _patient;
  List<MedicalCondition> _conditions = const [];
  List<Allergy> _allergies = const [];
  bool _loading = true;

  // Onboarding lets these be skipped, so they have to be fillable later.
  bool _editing = false;
  final _height = TextEditingController();
  final _weight = TextEditingController();
  String? _dob;
  String? _gender;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _saveMetrics() async {
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId == null) return;

    await _repo.updatePatient(patientId, {
      'height_cm': double.tryParse(_height.text.trim()),
      'weight_kg': double.tryParse(_weight.text.trim()),
      'dob': _dob,
      'gender': _gender,
    });
    ref.read(backupSyncProvider).queueBackup(patientId);
    if (mounted) setState(() => _editing = false);
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final patient = await _repo.getPatient(patientId);
    final conditions = await _repo.listConditions(patientId);
    final allergies = await _repo.listAllergies(patientId);
    if (!mounted) return;
    setState(() {
      _patient = patient;
      _conditions = conditions;
      _allergies = allergies;
      _height.text = patient?.heightCm?.toStringAsFixed(0) ?? '';
      _weight.text = patient?.weightKg?.toStringAsFixed(0) ?? '';
      _dob = patient?.dob;
      _gender = patient?.gender;
      _loading = false;
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final last = parts.length == 1
        ? [parts.first]
        : parts.toList().sublist(parts.length - 2);
    return last.map((p) => p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    if (_loading) {
      return const AppScreen(
          children: [Center(child: CircularProgressIndicator())]);
    }

    final p = _patient;
    if (p == null) {
      return AppScreen(children: [
        AppText(t.t('profile.title'), variant: TextVariant.title),
      ]);
    }

    final age = ageFromDob(p.dob);
    final bmi = (p.heightCm != null && p.weightKg != null && p.heightCm! > 0)
        ? p.weightKg! / ((p.heightCm! / 100) * (p.heightCm! / 100))
        : null;

    return AppScreen(
      onRefresh: _load,
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
                child: AppText(_initials(p.fullName),
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
                        if (age != null)
                          '$age ${t.t('profile.age').toLowerCase()}',
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
          actionLabel: _editing ? t.t('common.save') : t.t('common.edit'),
          onAction: () {
            if (_editing) {
              _saveMetrics();
            } else {
              setState(() => _editing = true);
            }
          },
        ),
        if (_editing)
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
                  value: _dob,
                  maximumDate: DateTime.now(),
                  onChanged: (v) => setState(() => _dob = v),
                ),
                ChipSelect<String>(
                  label: t.t('profile.gender'),
                  value: _gender,
                  options: [
                    ChipOption(
                        value: 'male', label: t.t('profile.genders.male')),
                    ChipOption(
                        value: 'female', label: t.t('profile.genders.female')),
                    ChipOption(
                        value: 'other', label: t.t('profile.genders.other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
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
                  value: bmi?.toStringAsFixed(1) ?? '—',
                  unit: ''),
            ],
          ),
        const SizedBox(height: Spacing.lg),

        SectionHeader(title: t.t('profile.medicalHistory')),
        if (_conditions.isEmpty)
          AppText(t.t('common.none'), color: TextColorKey.textFaint)
        else
          ..._conditions.map((c) => Padding(
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
        if (_allergies.isEmpty)
          AppText(t.t('common.none'), color: TextColorKey.textFaint)
        else
          ..._allergies.map((a) => Padding(
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
