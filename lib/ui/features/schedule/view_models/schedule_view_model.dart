import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/appointments_repository.dart';
import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/domain/models/models.dart';
import 'package:medremind/ui/core/date_format.dart';

/// Schedule state: upcoming appointments plus today's doses grouped by
/// part of day.
class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel({
    required this.patientId,
    this.doses = const DosesRepository(),
    this.appointments = const AppointmentsRepository(),
  });

  final int? patientId;
  final DosesRepository doses;
  final AppointmentsRepository appointments;

  List<TodayDose> _today = const [];
  List<TodayDose> get today => List.unmodifiable(_today);

  List<Appointment> _upcoming = const [];
  List<Appointment> get upcoming => List.unmodifiable(_upcoming);

  bool _loading = true;
  bool get loading => _loading;

  bool _disposed = false;

  /// The order the day runs in. Fixed rather than derived from the data, so
  /// evening never renders above morning.
  static const List<PartOfDay> slotOrder = [
    PartOfDay.morning,
    PartOfDay.noon,
    PartOfDay.evening,
    PartOfDay.night,
  ];

  /// Doses bucketed by part of day, in [slotOrder], skipping empty buckets.
  Map<PartOfDay, List<TodayDose>> get groupedDoses {
    final groups = <PartOfDay, List<TodayDose>>{};
    for (final d in _today) {
      groups.putIfAbsent(partOfDay(d.time), () => []).add(d);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.time.compareTo(b.time));
    }
    return {
      for (final slot in slotOrder)
        if (groups.containsKey(slot)) slot: groups[slot]!,
    };
  }

  /// Nothing at all to show — distinct from having appointments but no doses,
  /// which must not render the "no schedule" empty state.
  bool get isEmpty => _today.isEmpty && _upcoming.isEmpty;

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
    _upcoming = await appointments.listUpcomingAppointments(id);
    _loading = false;
    _notify();
  }

  Future<void> deleteAppointment(int id) async {
    await appointments.deleteAppointment(id);
    await load();
  }
}
