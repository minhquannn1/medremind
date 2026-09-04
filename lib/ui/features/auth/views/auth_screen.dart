import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/data/services/links.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_input.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/features/auth/view_models/auth_view_model.dart';

/// Sign in / sign up.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _name = TextEditingController();

  late final AuthViewModel _vm = AuthViewModel(
    signIn: ref.read(appStateProvider.notifier).signIn,
    signUp: ref.read(appStateProvider.notifier).signUp,
  );

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _submit() => _vm.submit(
        email: _email.text,
        password: _password.text,
        confirmPassword: _confirmPassword.text,
        name: _name.text,
      );

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _build(t),
    );
  }

  Widget _build(Translations t) {
    String? errorFor(AuthField f) {
      final key = _vm.errorKeyFor(f);
      return key == null ? null : t.t(key);
    }

    return AppScreen(
      children: [
        AppHeader(title: '', onBack: () => context.pop()),
        const SizedBox(height: Spacing.xxl),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services,
                color: AppColors.textInverse, size: 32),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        AppText(
          _vm.signUpMode ? t.t('auth.signup') : t.t('auth.login'),
          variant: TextVariant.title,
          center: true,
        ),
        const SizedBox(height: Spacing.sm),
        AppText(
          _vm.signUpMode
              ? t.t('auth.signupSubtitle')
              : t.t('auth.loginSubtitle'),
          color: TextColorKey.textMuted,
          center: true,
        ),
        const SizedBox(height: Spacing.xxl),

        if (_vm.signUpMode)
          AppInput(
            controller: _name,
            label: t.t('profile.fullName'),
            placeholder: t.t('profile.fullName'),
            icon: Icons.person_outline,
            error: errorFor(AuthField.name),
          ),
        AppInput(
          controller: _email,
          label: t.t('auth.email'),
          placeholder: 'you@example.com',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          error: errorFor(AuthField.email),
        ),
        AppInput(
          controller: _password,
          label: t.t('auth.password'),
          placeholder: '••••••••',
          icon: Icons.lock_outline,
          obscureText: true,
          obscureToggle: true,
          revealLabel: t.t('auth.showPassword'),
          hideLabel: t.t('auth.hidePassword'),
          error: errorFor(AuthField.password),
        ),

        // Sign-up only: a mistyped password that nobody can see would lock the
        // account on the very first attempt.
        if (_vm.signUpMode)
          AppInput(
            controller: _confirmPassword,
            label: t.t('auth.confirmPassword'),
            placeholder: '••••••••',
            icon: Icons.lock_outline,
            obscureText: true,
            obscureToggle: true,
            revealLabel: t.t('auth.showPassword'),
            hideLabel: t.t('auth.hidePassword'),
            error: errorFor(AuthField.confirmPassword),
          ),

        if (_vm.signUpMode) ...[
          _PolicyConsent(
            accepted: _vm.acceptedPolicies,
            onChanged: _vm.setAcceptedPolicies,
            error: errorFor(AuthField.terms),
            t: t,
          ),
          const SizedBox(height: Spacing.lg),
        ],

        AppButton(
          label: _vm.signUpMode ? t.t('auth.signup') : t.t('auth.login'),
          size: ButtonSize.lg,
          loading: _vm.busy,
          onPressed: _submit,
        ),
        const SizedBox(height: Spacing.lg),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText(
              _vm.signUpMode ? t.t('auth.haveAccount') : t.t('auth.noAccount'),
              color: TextColorKey.textMuted,
            ),
            const SizedBox(width: Spacing.xs),
            GestureDetector(
              onTap: _vm.busy ? null : _vm.toggleMode,
              child: AppText(
                _vm.signUpMode ? t.t('auth.login') : t.t('auth.signup'),
                variant: TextVariant.bodyStrong,
                color: TextColorKey.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xxl),

        // The account is optional: App Store Guideline 5.1.1(v) forbids gating
        // on-device features behind a sign-in, and everything except cloud
        // backup works without one.
        AppText(
          t.t('auth.accountOptionalNote'),
          variant: TextVariant.caption,
          color: TextColorKey.textMuted,
          center: true,
        ),
        const SizedBox(height: Spacing.md),
        AppButton(
          label: t.t('auth.continueWithoutAccount'),
          variant: ButtonVariant.ghost,
          disabled: _vm.busy,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}

/// Consent to the terms and privacy policy, with both documents reachable
/// before agreeing — a checkbox next to text nobody can open is not consent.
class _PolicyConsent extends StatelessWidget {
  const _PolicyConsent({
    required this.accepted,
    required this.onChanged,
    required this.error,
    required this.t,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final String? error;
  final Translations t;

  @override
  Widget build(BuildContext context) {
    final linkStyle = textStyleFor(TextVariant.caption).copyWith(
      color: AppColors.primary,
      fontWeight: FontWeights.semibold,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              checked: accepted,
              label: t.t('auth.acceptTerms'),
              child: Checkbox(
                value: accepted,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.primary,
                side: BorderSide(
                  color: error != null ? AppColors.danger : AppColors.borderStrong,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.sm / 2),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Tapping the words toggles too — the box alone is a small
                    // target, especially for older users.
                    GestureDetector(
                      onTap: () => onChanged(!accepted),
                      child: AppText('${t.t('auth.acceptPrefix')} ',
                          variant: TextVariant.caption,
                          color: TextColorKey.textMuted),
                    ),
                    GestureDetector(
                      onTap: () => openExternalUrl(termsUrl),
                      child: Text(t.t('auth.acceptTerms'), style: linkStyle),
                    ),
                    AppText(' ${t.t('auth.acceptAnd')} ',
                        variant: TextVariant.caption,
                        color: TextColorKey.textMuted),
                    GestureDetector(
                      onTap: () => openExternalUrl(privacyPolicyUrl),
                      child: Text(t.t('auth.acceptPrivacy'), style: linkStyle),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs, left: Spacing.xs),
            child: AppText(error!,
                variant: TextVariant.caption, color: TextColorKey.danger),
          ),
      ],
    );
  }
}
