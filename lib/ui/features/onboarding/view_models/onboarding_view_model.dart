import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/services/doctor_sync_service.dart';

/// First-run profile creation, with an optional doctor pairing code.
class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({
    required this.accountUserId,
    required this.accountEmail,
    this.patients = const PatientsRepository(),
    this.doctors = const DoctorSyncApi(),
  });

  final int? accountUserId;
  final String? accountEmail;
  final PatientsRepository patients;
  final DoctorSyncApi doctors;

  String? dob;
  String? gender;

  bool _busy = false;
  bool get busy => _busy;

  /// i18n keys, separated so each message lands on its own field.
  String? _nameErrorKey;
  String? get nameErrorKey => _nameErrorKey;

  String? _pairErrorKey;
  String? get pairErrorKey => _pairErrorKey;

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

  /// Creates the profile and, when a code was supplied, links the doctor.
  /// Returns the new patient id, or null when something was rejected.
  ///
  /// The code is checked *before* the profile is created: a typo should be
  /// correctable on the spot rather than silently dropped, which would leave
  /// the user believing they are linked when they are not.
  Future<int?> start({
    required String fullName,
    required String heightCm,
    required String weightKg,
    required String pairCode,
  }) async {
    if (fullName.trim().isEmpty) {
      _nameErrorKey = 'auth.errorMissingFields';
      _notify();
      return null;
    }

    _busy = true;
    _nameErrorKey = null;
    _pairErrorKey = null;
    _notify();

    var paired = false;
    final code = pairCode.trim();
    if (code.isNotEmpty) {
      final res = await doctors.pairWithDoctor(code);
      if (!res.ok) {
        _busy = false;
        _pairErrorKey = res.error == PairError.invalidCode
            ? 'doctor.invalidCode'
            : 'doctor.networkError';
        _notify();
        return null;
      }
      paired = true;
    }

    final patientId = await patients.createPatient(
      fullName: fullName.trim(),
      dob: dob,
      gender: gender,
      heightCm: double.tryParse(heightCm.trim()),
      weightKg: double.tryParse(weightKg.trim()),
      accountUserId: accountUserId,
      accountEmail: accountEmail,
    );

    // Push straight away so the doctor sees a real profile, not an empty one.
    if (paired) await doctors.syncToDoctor(patientId);

    _busy = false;
    _notify();
    return patientId;
  }
}
