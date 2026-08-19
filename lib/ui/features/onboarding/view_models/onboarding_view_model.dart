import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/patients_repository.dart';

/// First-run profile creation.
class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({
    required this.accountUserId,
    required this.accountEmail,
    this.patients = const PatientsRepository(),
  });

  final int? accountUserId;
  final String? accountEmail;
  final PatientsRepository patients;

  String? dob;
  String? gender;

  bool _busy = false;
  bool get busy => _busy;

  String? _nameErrorKey;
  String? get nameErrorKey => _nameErrorKey;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDob(String? value) {
    dob = value;
    _notify();
  }

  void setGender(String? value) {
    gender = value;
    _notify();
  }

  /// Creates the profile and returns the new patient id, or null when a
  /// required field is missing.
  Future<int?> start({
    required String fullName,
    required String heightCm,
    required String weightKg,
  }) async {
    if (fullName.trim().isEmpty) {
      _nameErrorKey = 'auth.errorMissingFields';
      _notify();
      return null;
    }

    _busy = true;
    _nameErrorKey = null;
    _notify();

    final patientId = await patients.createPatient(
      fullName: fullName.trim(),
      dob: dob,
      gender: gender,
      heightCm: double.tryParse(heightCm.trim()),
      weightKg: double.tryParse(weightKg.trim()),
      accountUserId: accountUserId,
      accountEmail: accountEmail,
    );

    _busy = false;
    _notify();
    return patientId;
  }
}
