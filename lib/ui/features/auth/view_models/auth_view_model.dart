import 'package:flutter/foundation.dart';

import 'package:medremind/data/services/patient_auth_service.dart';

typedef SignInCallback = Future<AuthErrorCode?> Function(
    String email, String password);
typedef SignUpCallback = Future<AuthErrorCode?> Function(
    String email, String password, String name);

/// Which field a validation failure belongs to, so the view can mark the right
/// input instead of dropping one message at the bottom of the form.
enum AuthField { name, email, password, confirmPassword, terms }

class AuthValidationError {
  const AuthValidationError(this.field, this.messageKey);

  final AuthField field;
  final String messageKey;
}

/// Sign in / sign up state and rules.
///
/// Kept out of the widget so the sign-up rules — passwords matching, the terms
/// checkbox, which field an error belongs to — are testable as plain Dart.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required this.signIn, required this.signUp});

  /// Injected rather than reaching for the store, so the rules below can be
  /// tested without a database or a network.
  final SignInCallback signIn;
  final SignUpCallback signUp;

  bool _signUpMode = false;
  bool get signUpMode => _signUpMode;

  bool _busy = false;
  bool get busy => _busy;

  bool _acceptedPolicies = false;
  bool get acceptedPolicies => _acceptedPolicies;

  AuthValidationError? _validationError;
  AuthValidationError? get validationError => _validationError;

  /// Set when the server rejects the attempt, as opposed to a local rule.
  String? _serverErrorKey;
  String? get serverErrorKey => _serverErrorKey;

  /// The message for [field], if the current error belongs to it.
  String? errorKeyFor(AuthField field) {
    if (_validationError?.field == field) return _validationError!.messageKey;
    // Credential failures are shown against the password box, where the user
    // is looking after a failed sign-in.
    if (field == AuthField.password) return _serverErrorKey;
    return null;
  }

  void toggleMode() {
    _signUpMode = !_signUpMode;
    _validationError = null;
    _serverErrorKey = null;
    notifyListeners();
  }

  void setAcceptedPolicies(bool value) {
    _acceptedPolicies = value;
    // Clear the nag as soon as they tick it.
    if (_validationError?.field == AuthField.terms) _validationError = null;
    notifyListeners();
  }

  /// Local rules, checked before spending a network round trip.
  AuthValidationError? validate({
    required String email,
    required String password,
    required String confirmPassword,
    required String name,
  }) {
    if (_signUpMode && name.trim().isEmpty) {
      return const AuthValidationError(
          AuthField.name, 'auth.errorMissingFields');
    }
    if (email.trim().isEmpty) {
      return const AuthValidationError(
          AuthField.email, 'auth.errorMissingFields');
    }
    if (password.isEmpty) {
      return const AuthValidationError(
          AuthField.password, 'auth.errorMissingFields');
    }
    if (!_signUpMode) return null;

    // Sign-up only from here: a typo in a password you cannot see would
    // otherwise lock the account on the very first try.
    if (password.length < 8) {
      return const AuthValidationError(
          AuthField.password, 'auth.errorWeakPassword');
    }
    if (confirmPassword != password) {
      return const AuthValidationError(
          AuthField.confirmPassword, 'auth.errorPasswordMismatch');
    }
    if (!_acceptedPolicies) {
      return const AuthValidationError(
          AuthField.terms, 'auth.errorMustAccept');
    }
    return null;
  }

  /// Returns true when the user is through.
  Future<bool> submit({
    required String email,
    required String password,
    required String confirmPassword,
    required String name,
  }) async {
    final problem = validate(
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      name: name,
    );
    if (problem != null) {
      _validationError = problem;
      _serverErrorKey = null;
      notifyListeners();
      return false;
    }

    _busy = true;
    _validationError = null;
    _serverErrorKey = null;
    notifyListeners();

    final err = _signUpMode
        ? await signUp(email.trim(), password, name.trim())
        : await signIn(email.trim(), password);

    _busy = false;
    _serverErrorKey = err == null ? null : authErrorMessageKey(err);
    notifyListeners();
    return err == null;
  }
}
