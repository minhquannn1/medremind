import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/domain/models/models.dart';

/// One prescription with its medications and their schedules.
class PrescriptionDetailViewModel extends ChangeNotifier {
  PrescriptionDetailViewModel({
    required this.prescriptionId,
    this.prescriptions = const PrescriptionsRepository(),
  });

  final int prescriptionId;
  final PrescriptionsRepository prescriptions;

  Prescription? _prescription;
  Prescription? get prescription => _prescription;

  List<Medication> _medications = const [];
  List<Medication> get medications => List.unmodifiable(_medications);

  final Map<int, List<String>> _times = {};

  bool _loading = true;
  bool get loading => _loading;

  bool _disposed = false;

  bool get isCompleted => _prescription?.status == 'completed';

  /// Sorted intake times for a medication, ready to join for display.
  List<String> timesFor(int medicationId) =>
      List.unmodifiable(_times[medicationId] ?? const []);

  /// Doctor and clinic joined, or null when neither is filled in.
  String? get title {
    final p = _prescription;
    if (p == null) return null;
    final parts = [p.doctorName, p.clinic]
        .where((s) => s != null && s.trim().isNotEmpty)
        .cast<String>();
    return parts.isEmpty ? null : parts.join(' · ');
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
    _prescription = await prescriptions.getPrescription(prescriptionId);
    _medications = await prescriptions.listMedications(prescriptionId);
    _times.clear();
    for (final m in _medications) {
      final times = await prescriptions.listScheduleTimes(m.id);
      _times[m.id] = (times.map((t) => t.time).toList())..sort();
    }
    _loading = false;
    _notify();
  }

  Future<void> toggleStatus() async {
    final p = _prescription;
    if (p == null) return;
    await prescriptions.updatePrescriptionStatus(
      p.id,
      isCompleted ? 'active' : 'completed',
    );
    await load();
  }

  Future<void> delete() => prescriptions.deletePrescription(prescriptionId);
}
