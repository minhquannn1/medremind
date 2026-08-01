import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/ai_scanner_service.dart';
import 'package:medremind/domain/models/models.dart';

/// One medication: schedule, stock and the AI explanation.
class MedicationDetailViewModel extends ChangeNotifier {
  MedicationDetailViewModel({
    required this.medicationId,
    required this.language,
    this.prescriptions = const PrescriptionsRepository(),
    this.scanner = const AiScannerApi(),
  });

  final int medicationId;
  final String language;
  final PrescriptionsRepository prescriptions;
  final AiScannerApi scanner;

  Medication? _medication;
  Medication? get medication => _medication;

  List<ScheduleTime> _times = const [];
  List<ScheduleTime> get times => List.unmodifiable(_times);

  bool _loading = true;
  bool get loading => _loading;

  bool _explaining = false;
  bool get explaining => _explaining;

  bool _explainFailed = false;
  bool get explainFailed => _explainFailed;

  bool _disposed = false;

  bool get hasExplanation =>
      (_medication?.explanation ?? '').trim().isNotEmpty;

  /// Stock is "low" at a fifth of the original quantity or less. Null when the
  /// medication has no tracked amount, which must not read as "low".
  bool get isLowStock {
    final remaining = _medication?.quantityRemaining;
    final total = _medication?.quantityTotal;
    if (remaining == null || total == null || total <= 0) return false;
    return remaining <= total * 0.2;
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
    _medication = await prescriptions.getMedication(medicationId);
    _times = (await prescriptions.listScheduleTimes(medicationId))
      ..sort((a, b) => a.time.compareTo(b.time));
    _loading = false;
    _notify();
  }

  Future<void> changeTime(ScheduleTime st, String value) async {
    await prescriptions.updateScheduleTime(st.id, value);
    await load();
  }

  /// Returns true when an explanation was written.
  Future<bool> explain() async {
    final m = _medication;
    if (m == null) return false;

    _explaining = true;
    _explainFailed = false;
    _notify();

    final text = await scanner.explainMedication(m.name, lang: language);

    if (text == null) {
      _explaining = false;
      _explainFailed = true;
      _notify();
      return false;
    }

    await prescriptions.updateMedicationExplanation(m.id, text, language);
    _explaining = false;
    await load();
    return true;
  }
}
