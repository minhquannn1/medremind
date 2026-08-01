import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/data/services/backup_sync_service.dart';

/// Confirming the dose behind a tapped reminder.
class DoseConfirmViewModel extends ChangeNotifier {
  DoseConfirmViewModel({
    required this.patientId,
    required this.medicationId,
    required this.time,
    this.doses = const DosesRepository(),
    this.backupSync,
  });

  final int? patientId;
  final int medicationId;
  final String time;
  final DosesRepository doses;
  final BackupSyncApi? backupSync;

  TodayDose? _dose;
  TodayDose? get dose => _dose;

  bool _loading = true;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  bool _disposed = false;

  /// A reminder can outlive its dose — a finished course, or a prescription
  /// deleted after the alert was scheduled.
  bool get isStale => !_loading && _dose == null;

  bool get alreadyResolved =>
      _dose != null && _dose!.status != DoseStatus.pending;

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

    final today = await doses.getDosesForDay(id);
    TodayDose? match;
    for (final d in today) {
      if (d.medicationId == medicationId && d.time == time) {
        match = d;
        break;
      }
    }
    _dose = match;
    _loading = false;
    _notify();
  }

  /// Returns true when the dose was recorded, so the view knows to pop.
  Future<bool> mark(DoseStatus status) async {
    final d = _dose;
    if (d == null) return false;

    _saving = true;
    _notify();

    await doses.markDose(d.id, status);
    final id = patientId;
    if (id != null) backupSync?.queueBackup(id);

    _saving = false;
    _notify();
    return true;
  }
}
