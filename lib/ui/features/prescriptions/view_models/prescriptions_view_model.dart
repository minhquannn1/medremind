import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/domain/models/models.dart';

/// The prescription list, with each entry's medication count.
class PrescriptionsViewModel extends ChangeNotifier {
  PrescriptionsViewModel({
    required this.patientId,
    this.prescriptions = const PrescriptionsRepository(),
  });

  final int? patientId;
  final PrescriptionsRepository prescriptions;

  List<Prescription> _items = const [];
  List<Prescription> get items => List.unmodifiable(_items);

  final Map<int, int> _medicationCounts = {};

  bool _loading = true;
  bool get loading => _loading;

  bool _disposed = false;

  int medicationCount(int prescriptionId) =>
      _medicationCounts[prescriptionId] ?? 0;

  /// Doctor and clinic joined for the card title, or null when neither is
  /// filled in so the view can fall back to a generic label.
  String? titleFor(Prescription p) {
    final parts = [p.doctorName, p.clinic]
        .where((s) => s != null && s.trim().isNotEmpty)
        .cast<String>();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  bool isCompleted(Prescription p) => p.status == 'completed';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    final id = patientId;
    if (id == null) {
      _loading = false;
      if (!_disposed) notifyListeners();
      return;
    }

    _items = await prescriptions.listPrescriptions(id);
    _medicationCounts.clear();
    for (final p in _items) {
      _medicationCounts[p.id] = (await prescriptions.listMedications(p.id)).length;
    }
    _loading = false;
    if (!_disposed) notifyListeners();
  }
}
