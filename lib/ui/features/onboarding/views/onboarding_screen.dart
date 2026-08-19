import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_input.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/fields.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

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

  late final OnboardingViewModel _vm = OnboardingViewModel(
    accountUserId: ref.read(appStateProvider).account?.userId,
    accountEmail: ref.read(appStateProvider).account?.email,
  );

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
    _vm.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final patientId = await _vm.start(
      fullName: _name.text,
      heightCm: _height.text,
      weightKg: _weight.text,
    );
    if (patientId == null || !mounted) return;
    await ref.read(appStateProvider.notifier).completeOnboarding(patientId);
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
          error: _vm.nameErrorKey == null ? null : t.t(_vm.nameErrorKey!),
        ),
        DateField(
          label: t.t('profile.dob'),
          value: _vm.dob,
          maximumDate: DateTime.now(),
          onChanged: _vm.setDob,
        ),
        ChipSelect<String>(
          label: t.t('profile.gender'),
          value: _vm.gender,
          options: [
            ChipOption(value: 'male', label: t.t('profile.genders.male')),
            ChipOption(value: 'female', label: t.t('profile.genders.female')),
            ChipOption(value: 'other', label: t.t('profile.genders.other')),
          ],
          onChanged: _vm.setGender,
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

        AppButton(
          label: t.t('onboarding.start'),
          size: ButtonSize.lg,
          loading: _vm.busy,
          onPressed: _start,
        ),
      ],
    );
  }
}
