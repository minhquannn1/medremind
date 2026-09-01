import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/appointments_repository.dart';
import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/services/backup_sync_service.dart';
import 'package:medremind/domain/models/models.dart';

/// State and behaviour for the home screen.
///
/// The screen used to load and mutate data itself, which meant its logic could
/// only be exercised by building the widget tree. Here it is plain Dart: the
/// greeting bucket, the "everything taken" condition and marking a dose can
/// each be tested directly.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.patientId,
    this.doses = const DosesRepository(),
    this.patients = const PatientsRepository(),
    this.appointments = const AppointmentsRepository(),
    this.backupSync,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int? patientId;
  final DosesRepository doses;
  final PatientsRepository patients;
  final AppointmentsRepository appointments;
  final BackupSyncApi? backupSync;

  /// Injectable so the greeting and "is it due" logic are testable without
  /// waiting for the clock.
  final DateTime Function() _now;

  List<TodayDose> _today = const [];
  List<TodayDose> get today => List.unmodifiable(_today);

  AdherenceStat _adherence = const AdherenceStat(taken: 0, total: 0, ratio: 1);
  AdherenceStat get adherence => _adherence;

  Patient? _patient;
  Patient? get patient => _patient;

  /// The name to greet, or null when there is none. Onboarding can be skipped
  /// entirely, so a blank name is a normal state rather than an error.
  String? get displayName {
    final name = _patient?.fullName.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  Appointment? _nextAppointment;
  Appointment? get nextAppointment => _nextAppointment;

  bool _loading = true;
  bool get loading => _loading;

  bool _disposed = false;

  /// Doses still waiting to be confirmed.
  List<TodayDose> get pending =>
      _today.where((d) => d.status == DoseStatus.pending).toList();

  /// True only when there is something scheduled and none of it is pending —
  /// an empty day is not an achievement.
  bool get allDone => _today.isNotEmpty && pending.isEmpty;

  /// "—" rather than 0% when nothing was due: a patient with no doses has not
  /// failed to take them.
  String get adherenceLabel => _adherence.total == 0
      ? '—'
      : '${(_adherence.ratio * 100).round()}%';

  String get adherenceCount => '${_adherence.taken}/${_adherence.total}';

  /// Part of the day, for the greeting.
  GreetingSlot get greeting {
    final hour = _now().hour;
    if (hour < 11) return GreetingSlot.morning;
    if (hour < 18) return GreetingSlot.afternoon;
    return GreetingSlot.evening;
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

    _today = await doses.getDosesForDay(id);
    _adherence = await doses.getAdherence(id, days: 7);
    _patient = await patients.getPatient(id);
    final upcoming = await appointments.listUpcomingAppointments(id);
    _nextAppointment = upcoming.isEmpty ? null : upcoming.first;
    _loading = false;
    _notify();
  }

  Future<void> mark(TodayDose dose, DoseStatus status) async {
    await doses.markDose(dose.id, status);
    final id = patientId;
    if (id != null) backupSync?.queueBackup(id);
    await load();
  }
}

enum GreetingSlot { morning, afternoon, evening }
