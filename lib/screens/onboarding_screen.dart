import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_button.dart';
import '../components/app_input.dart';
import '../components/app_text.dart';
import '../components/controls.dart';
import '../components/fields.dart';
import '../components/layout.dart';
import '../features/sync/doctor_sync.dart';
import '../store/app_state.dart';
import '../theme/tokens.dart';

/// First-run profile creation. Ported from `app/onboarding.tsx`.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _pairCode = TextEditingController();

  String? _dob;
  String? _gender;
  bool _busy = false;
  String? _error;
  String? _pairError;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the account so the user rarely retypes their own name.
    final account = ref.read(appStateProvider).account;
    if (account != null && account.name.isNotEmpty) _name.text = account.name;
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    _pairCode.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final t = ref.read(translationsProvider);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = t.t('auth.errorMissingFields'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _pairError = null;
    });

    // Check the doctor code before creating anything: a typo should be fixable
    // here rather than silently dropped, leaving the user think they are
    // linked when they are not.
    const doctors = DoctorSyncApi();
    var paired = false;
    final code = _pairCode.text.trim();
    if (code.isNotEmpty) {
      final res = await doctors.pairWithDoctor(code);
      if (!res.ok) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _pairError = res.error == PairError.invalidCode
              ? t.t('doctor.invalidCode')
              : t.t('doctor.networkError');
        });
        return;
      }
      paired = true;
    }

    final app = ref.read(appStateProvider);
    final patientId = await ref.read(patientsRepositoryProvider).createPatient(
          fullName: _name.text.trim(),
          dob: _dob,
          gender: _gender,
          heightCm: double.tryParse(_height.text.trim()),
          weightKg: double.tryParse(_weight.text.trim()),
          accountUserId: app.account?.userId,
          accountEmail: app.account?.email,
        );

    await ref.read(appStateProvider.notifier).completeOnboarding(patientId);
    // Push straight away so the doctor sees a real profile, not an empty one.
    if (paired) await doctors.syncToDoctor(patientId);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return AppScreen(
      children: [
        const SizedBox(height: Spacing.xl),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.medical_services,
              color: AppColors.textInverse, size: 34),
        ),
        const SizedBox(height: Spacing.lg),
        AppText(t.t('onboarding.welcomeTitle'), variant: TextVariant.title),
        const SizedBox(height: Spacing.sm),
        AppText(t.t('onboarding.welcomeBody'), color: TextColorKey.textMuted),
        const SizedBox(height: Spacing.md),
        // Medical disclaimer — App Review guideline 1.4.1.
        AppText(t.t('onboarding.disclaimer'), variant: TextVariant.caption,
            color: TextColorKey.textFaint),
        const SizedBox(height: Spacing.xxl),

        AppText(t.t('onboarding.createProfile'),
            variant: TextVariant.subheading),
        const SizedBox(height: Spacing.xs),
        AppText(t.t('onboarding.profileHint'),
            variant: TextVariant.caption, color: TextColorKey.textFaint),
        const SizedBox(height: Spacing.lg),

        AppInput(
          controller: _name,
          label: t.t('profile.fullName'),
          icon: Icons.person_outline,
          error: _error,
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
            ChipOption(value: 'male', label: t.t('profile.genders.male')),
            ChipOption(value: 'female', label: t.t('profile.genders.female')),
            ChipOption(value: 'other', label: t.t('profile.genders.other')),
          ],
          onChanged: (v) => setState(() => _gender = v),
        ),
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

        // Optional: most users pair later from Settings, but entering the
        // code here saves a step for anyone handed one at the clinic.
        SectionHeader(title: t.t('doctor.title')),
        AppText('${t.t('doctor.enterCodeHint')} (${t.t('common.optional')})',
            variant: TextVariant.caption, color: TextColorKey.textFaint),
        const SizedBox(height: Spacing.md),
        AppInput(
          controller: _pairCode,
          placeholder: 'MED-XXXXXX',
          icon: Icons.qr_code,
          autocorrect: false,
          error: _pairError,
        ),

        AppButton(
          label: t.t('onboarding.start'),
          size: ButtonSize.lg,
          loading: _busy,
          onPressed: _start,
        ),
      ],
    );
  }
}
