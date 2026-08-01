import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/domain/models/medication_draft.dart';

/// One problem found while validating the form, with the medication it
/// belongs to so the view can mark that row rather than only flashing a
/// message the user has to map back themselves.
class PrescriptionFormError {
  const PrescriptionFormError({
    required this.messageKey,
    required this.params,
    this.draftKey,
  });

  final String messageKey;
  final Map<String, Object?> params;
  final String? draftKey;
}

/// Creating a prescription, by hand or pre-filled from a scan.
class PrescriptionFormViewModel extends ChangeNotifier {
  PrescriptionFormViewModel({
    required this.patientId,
    List<MedicationDraft>? initialDrafts,
    this.prescriptions = const PrescriptionsRepository(),
  }) : drafts = (initialDrafts == null || initialDrafts.isEmpty)
            ? [MedicationDraft.empty()]
            : List.of(initialDrafts);

  final int? patientId;
  final PrescriptionsRepository prescriptions;
  final List<MedicationDraft> drafts;

  String? issuedDate;

  bool _saving = false;
  bool get saving => _saving;

  PrescriptionFormError? _error;
  PrescriptionFormError? get error => _error;

  final Set<String> _incompleteDraftKeys = {};

  bool _disposed = false;

  bool isIncomplete(MedicationDraft d) => _incompleteDraftKeys.contains(d.key);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setIssuedDate(String? value) {
    issuedDate = value;
    _notify();
  }

  void addDraft() {
    drafts.add(MedicationDraft.empty());
    _notify();
  }

  void removeDraft(MedicationDraft d) {
    drafts.remove(d);
    _incompleteDraftKeys.remove(d.key);
    _notify();
  }

  /// A row nobody typed into is an unused slot, not a mistake — as long as it
  /// is not the only row.
  bool _isBlankSlot(MedicationDraft d) =>
      d.name.trim().isEmpty &&
      d.dosage.trim().isEmpty &&
      d.notes.trim().isEmpty &&
      drafts.length > 1;

  /// The first problem, or null when the form is complete. Marks every bad
  /// row, not just the first.
  PrescriptionFormError? validate() {
    _incompleteDraftKeys.clear();
    PrescriptionFormError? first;

    for (var i = 0; i < drafts.length; i++) {
      final d = drafts[i];
      if (_isBlankSlot(d)) continue;
      final position = i + 1;

      if (d.name.trim().isEmpty) {
        _incompleteDraftKeys.add(d.key);
        first ??= PrescriptionFormError(
          messageKey: 'prescriptions.errorMissingName',
          params: {'index': position},
          draftKey: d.key,
        );
        continue;
      }
      if (d.times.isEmpty) {
        _incompleteDraftKeys.add(d.key);
        first ??= PrescriptionFormError(
          messageKey: 'prescriptions.errorMissingTime',
          params: {'index': position, 'name': d.name.trim()},
          draftKey: d.key,
        );
      }
    }

    if (!drafts.any((d) => d.name.trim().isNotEmpty)) {
      first ??= const PrescriptionFormError(
        messageKey: 'prescriptions.errorNoMedication',
        params: {},
      );
    }
    return first;
  }

  /// Saves and returns the new prescription id, or null when validation or
  /// the session blocked it.
  Future<int?> save({
    required String doctorName,
    required String clinic,
    required String notes,
  }) async {
    final problem = validate();
    if (problem != null) {
      _error = problem;
      _notify();
      return null;
    }

    final id = patientId;
    if (id == null) return null;

    _saving = true;
    _error = null;
    _notify();

    String? orNull(String v) => v.trim().isEmpty ? null : v.trim();

    final prescriptionId = await prescriptions.createPrescription(
      PrescriptionInput(
        patientId: id,
        doctorName: orNull(doctorName),
        clinic: orNull(clinic),
        issuedDate: issuedDate,
        notes: orNull(notes),
        medications: drafts
            .where((d) => d.name.trim().isNotEmpty)
            .map((d) => d.toInput())
            .toList(),
      ),
    );

    _saving = false;
    _notify();
    return prescriptionId;
  }
}
