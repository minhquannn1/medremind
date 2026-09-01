import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/services/backup_sync_service.dart';
import 'package:medremind/domain/models/models.dart';
import 'package:medremind/ui/core/date_format.dart';

/// Profile state: identity, body metrics, conditions and allergies.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required this.patientId,
    this.patients = const PatientsRepository(),
    this.backupSync,
  });

  final int? patientId;
  final PatientsRepository patients;
  final BackupSyncApi? backupSync;

  Patient? _patient;
  Patient? get patient => _patient;

  List<MedicalCondition> _conditions = const [];
  List<MedicalCondition> get conditions => List.unmodifiable(_conditions);

  List<Allergy> _allergies = const [];
  List<Allergy> get allergies => List.unmodifiable(_allergies);

  bool _loading = true;
  bool get loading => _loading;

  bool _editing = false;
  bool get editing => _editing;

  // Draft values while editing, so cancelling leaves the record untouched.
  String nameDraft = '';
  String heightDraft = '';
  String weightDraft = '';
  String? dobDraft;
  String? genderDraft;

  bool _disposed = false;

  int? get age => ageFromDob(_patient?.dob);

  /// The name to show, or null when the user skipped onboarding and never
  /// filled one in. Blank is a normal state, not an error.
  String? get displayName {
    final name = _patient?.fullName.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  /// Body mass index, or null when either measurement is missing. Guards a
  /// zero height, which would otherwise divide by zero and render "Infinity".
  double? get bmi {
    final h = _patient?.heightCm;
    final w = _patient?.weightKg;
    if (h == null || w == null || h <= 0) return null;
    final metres = h / 100;
    return w / (metres * metres);
  }

  /// Up to two initials, taken from the end of the name — Vietnamese names put
  /// the given name last, so "Nguyễn Văn An" should read "VA", not "NV".
  String get initials {
    final parts = (_patient?.fullName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final tail = parts.length == 1 ? parts : parts.sublist(parts.length - 2);
    return tail.map((p) => p[0]).join().toUpperCase();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final id = patientId;
    if (id == null) {
      _loading = false;
      _notify();
      return;
    }

    _patient = await patients.getPatient(id);
    _conditions = await patients.listConditions(id);
    _allergies = await patients.listAllergies(id);
    _resetDrafts();
    _loading = false;
    _notify();
  }

  void _resetDrafts() {
    nameDraft = _patient?.fullName ?? '';
    heightDraft = _patient?.heightCm?.toStringAsFixed(0) ?? '';
    weightDraft = _patient?.weightKg?.toStringAsFixed(0) ?? '';
    dobDraft = _patient?.dob;
    genderDraft = _patient?.gender;
  }

  void startEditing() {
    _resetDrafts();
    _editing = true;
    _notify();
  }

  void cancelEditing() {
    _resetDrafts();
    _editing = false;
    _notify();
  }

  void setDob(String? value) {
    dobDraft = value;
    _notify();
  }

  void setGender(String? value) {
    genderDraft = value;
    _notify();
  }

  Future<void> saveMetrics() async {
    final id = patientId;
    if (id == null) return;

    await patients.updatePatient(id, {
      'full_name': nameDraft.trim(),
      'height_cm': double.tryParse(heightDraft.trim()),
      'weight_kg': double.tryParse(weightDraft.trim()),
      'dob': dobDraft,
      'gender': genderDraft,
    });
    backupSync?.queueBackup(id);
    _editing = false;
    await load();
  }
}
