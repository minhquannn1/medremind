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

  /// Creates the profile and returns the new patient id.
  ///
  /// Every field is optional, including the name. App Store Guideline
  /// 5.1.1(v) does not allow an app to demand personal information before it
  /// will work, and none of this is needed to set a reminder — it only makes
  /// the profile screen useful. Anything left blank can be filled in later
  /// under Profile.
  Future<int?> start({
    String fullName = '',
    String heightCm = '',
    String weightKg = '',
  }) async {
    _busy = true;
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
