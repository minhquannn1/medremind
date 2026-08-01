import 'package:flutter_test/flutter_test.dart';

import 'package:medremind/data/services/patient_auth_service.dart';
import 'package:medremind/ui/features/auth/view_models/auth_view_model.dart';

void main() {
  AuthViewModel build({
    AuthErrorCode? signInError,
    AuthErrorCode? signUpError,
    List<String>? calls,
  }) {
    return AuthViewModel(
      signIn: (email, password) async {
        calls?.add('signIn:$email');
        return signInError;
      },
      signUp: (email, password, name) async {
        calls?.add('signUp:$email:$name');
        return signUpError;
      },
    );
  }

  group('sign-in validation', () {
    test('an empty email is flagged on the email field', () async {
      final vm = build();
      final ok = await vm.submit(
          email: '  ', password: 'secret123', confirmPassword: '', name: '');

      expect(ok, isFalse);
      expect(vm.errorKeyFor(AuthField.email), 'auth.errorMissingFields');
    });

    test('sign-in ignores the confirm field and the checkbox', () async {
      final calls = <String>[];
      final vm = build(calls: calls);

      final ok = await vm.submit(
        email: 'a@b.com',
        password: 'anything',
        confirmPassword: '',
        name: '',
      );

      expect(ok, isTrue, reason: 'sign-up rules must not block signing in');
      expect(calls, ['signIn:a@b.com']);
    });

    test('a rejected sign-in shows against the password field', () async {
      final vm = build(signInError: AuthErrorCode.invalidCredentials);
      await vm.submit(
          email: 'a@b.com', password: 'nope', confirmPassword: '', name: '');

      expect(vm.errorKeyFor(AuthField.password),
          'auth.errorInvalidCredentials');
    });
  });

  group('sign-up validation', () {
    AuthViewModel signUpVm({List<String>? calls, AuthErrorCode? error}) {
      final vm = build(calls: calls, signUpError: error);
      vm.toggleMode();
      return vm;
    }

    test('requires a name', () async {
      final vm = signUpVm();
      vm.setAcceptedPolicies(true);
      final ok = await vm.submit(
        email: 'a@b.com',
        password: 'secret123',
        confirmPassword: 'secret123',
        name: '   ',
      );

      expect(ok, isFalse);
      expect(vm.errorKeyFor(AuthField.name), 'auth.errorMissingFields');
    });

    test('rejects a password shorter than 8 characters', () async {
      final vm = signUpVm();
      vm.setAcceptedPolicies(true);
      final ok = await vm.submit(
        email: 'a@b.com',
        password: 'short',
        confirmPassword: 'short',
        name: 'A',
      );

      expect(ok, isFalse);
      expect(vm.errorKeyFor(AuthField.password), 'auth.errorWeakPassword');
    });

    test('a mismatched confirmation blocks sign-up', () async {
      final calls = <String>[];
      final vm = signUpVm(calls: calls);
      vm.setAcceptedPolicies(true);

      final ok = await vm.submit(
        email: 'a@b.com',
        password: 'secret123',
        confirmPassword: 'secret124',
        name: 'A',
      );

      expect(ok, isFalse);
      expect(vm.errorKeyFor(AuthField.confirmPassword),
          'auth.errorPasswordMismatch');
      expect(calls, isEmpty,
          reason: 'a typo must not reach the server and create the account');
    });

    test('unchecked policies block sign-up', () async {
      final calls = <String>[];
      final vm = signUpVm(calls: calls);

      final ok = await vm.submit(
        email: 'a@b.com',
        password: 'secret123',
        confirmPassword: 'secret123',
        name: 'A',
      );

      expect(ok, isFalse);
      expect(vm.errorKeyFor(AuthField.terms), 'auth.errorMustAccept');
      expect(calls, isEmpty);
    });

    test('succeeds once everything matches and is accepted', () async {
      final calls = <String>[];
      final vm = signUpVm(calls: calls);
      vm.setAcceptedPolicies(true);

      final ok = await vm.submit(
        email: ' A@b.com ',
        password: 'secret123',
        confirmPassword: 'secret123',
        name: ' Quan ',
      );

      expect(ok, isTrue);
      expect(calls, ['signUp:A@b.com:Quan'], reason: 'trimmed before sending');
      expect(vm.errorKeyFor(AuthField.terms), isNull);
    });

    test('ticking the box clears the consent error', () async {
      final vm = signUpVm();
      await vm.submit(
        email: 'a@b.com',
        password: 'secret123',
        confirmPassword: 'secret123',
        name: 'A',
      );
      expect(vm.errorKeyFor(AuthField.terms), isNotNull);

      vm.setAcceptedPolicies(true);
      expect(vm.errorKeyFor(AuthField.terms), isNull,
          reason: 'the message should go the moment the user complies');
    });
  });

  group('mode toggle', () {
    test('switching modes clears stale errors', () async {
      final vm = build(signInError: AuthErrorCode.invalidCredentials);
      await vm.submit(
          email: 'a@b.com', password: 'x', confirmPassword: '', name: '');
      expect(vm.errorKeyFor(AuthField.password), isNotNull);

      vm.toggleMode();
      expect(vm.signUpMode, isTrue);
      expect(vm.errorKeyFor(AuthField.password), isNull);
    });

    test('consent does not carry over from a previous attempt', () {
      final vm = build();
      expect(vm.acceptedPolicies, isFalse,
          reason: 'consent must be an explicit action every time');
    });

    test('notifies the view on every state change', () {
      final vm = build();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.toggleMode();
      vm.setAcceptedPolicies(true);
      expect(notifications, 2);
    });
  });
}
