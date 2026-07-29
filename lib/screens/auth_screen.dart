import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_button.dart';
import '../components/app_input.dart';
import '../components/app_text.dart';
import '../components/layout.dart';
import '../features/auth/patient_auth.dart';
import '../store/app_state.dart';
import '../theme/tokens.dart';

/// Sign in / sign up. Ported from `app/auth.tsx`.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool _signUpMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = ref.read(translationsProvider);
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();

    if (email.isEmpty || password.isEmpty || (_signUpMode && name.isEmpty)) {
      setState(() => _error = t.t('auth.errorMissingFields'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final notifier = ref.read(appStateProvider.notifier);
    final AuthErrorCode? err = _signUpMode
        ? await notifier.signUp(email, password, name)
        : await notifier.signIn(email, password);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err == null ? null : t.t(authErrorMessageKey(err));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return AppScreen(
      children: [
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
          _signUpMode ? t.t('auth.signup') : t.t('auth.login'),
          variant: TextVariant.title,
          center: true,
        ),
        const SizedBox(height: Spacing.sm),
        AppText(
          _signUpMode ? t.t('auth.signupSubtitle') : t.t('auth.loginSubtitle'),
          color: TextColorKey.textMuted,
          center: true,
        ),
        const SizedBox(height: Spacing.xxl),

        if (_signUpMode)
          AppInput(
            controller: _name,
            label: t.t('profile.fullName'),
            icon: Icons.person_outline,
          ),
        AppInput(
          controller: _email,
          label: t.t('auth.email'),
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
        ),
        AppInput(
          controller: _password,
          label: t.t('auth.password'),
          icon: Icons.lock_outline,
          obscureText: true,
          obscureToggle: true,
          revealLabel: t.t('auth.showPassword'),
          hideLabel: t.t('auth.hidePassword'),
          error: _error,
        ),

        AppButton(
          label: _signUpMode ? t.t('auth.signup') : t.t('auth.login'),
          size: ButtonSize.lg,
          loading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: Spacing.lg),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText(
              _signUpMode ? t.t('auth.haveAccount') : t.t('auth.noAccount'),
              color: TextColorKey.textMuted,
            ),
            const SizedBox(width: Spacing.xs),
            GestureDetector(
              onTap: _busy
                  ? null
                  : () => setState(() {
                        _signUpMode = !_signUpMode;
                        _error = null;
                      }),
              child: AppText(
                _signUpMode ? t.t('auth.login') : t.t('auth.signup'),
                variant: TextVariant.bodyStrong,
                color: TextColorKey.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
