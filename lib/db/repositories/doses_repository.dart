import '../../lib_date.dart';
import '../database.dart';
import '../models.dart';
import 'prescriptions_repository.dart';

/// Dose logs: lazy generation, marking taken/skipped, history and adherence.
/// Ported from `src/db/repositories/doses.ts`.

enum DoseStatus { pending, taken, skipped, missed }

DoseStatus doseStatusFromString(String? s) {
  switch (s) {
    case 'taken':
      return DoseStatus.taken;
    case 'skipped':
      return DoseStatus.skipped;
    case 'missed':
      return DoseStatus.missed;
    default:
      return DoseStatus.pending;
  }
}

String doseStatusToString(DoseStatus s) => s.name;

class TodayDose {
  final int id;
  final int medicationId;
  final String medicationName;
  final String? form;
  final String? dosage;
  final String? relationToMeal;
  final String? takeWith;
  final String? imageUri;
  final String scheduledAt;
  final String time; // HH:mm
  final DoseStatus status;
  final double doseAmount;

  const TodayDose({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    this.form,
    this.dosage,
    this.relationToMeal,
    this.takeWith,
    this.imageUri,
    required this.scheduledAt,
    required this.time,
    required this.status,
    required this.doseAmount,
  });
}

class HistoryDose {
  final int id;
  final String medicationName;
  final String scheduledAt;
  final String time;
  final DoseStatus status;
  final String? takenAt;

  const HistoryDose({
    required this.id,
    required this.medicationName,
    required this.scheduledAt,
    required this.time,
    required this.status,
    this.takenAt,
  });
}

class HistoryDay {
  final String date; // YYYY-MM-DD
  final List<HistoryDose> doses;
  final int taken;
  final int total;

  const HistoryDay({
    required this.date,
    required this.doses,
    required this.taken,
    required this.total,
  });
}

class AdherenceStat {
  final int taken;
  final int total;
  final double ratio;

  const AdherenceStat({
    required this.taken,
    required this.total,
    required this.ratio,
  });
}

class DosesRepository {
  const DosesRepository({
    this.prescriptions = const PrescriptionsRepository(),
  });

  final PrescriptionsRepository prescriptions;

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  static String _hhmm(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _ymd(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// A medication only generates doses inside its start/duration window.
  static bool _withinMedicationWindow(
    String? startDate,
    int? durationDays,
    DateTime day,
  ) {
    if (startDate == null || startDate.isEmpty) return true;
    final parsed = DateTime.tryParse(startDate);
    if (parsed == null) return true;
    final start = _startOfDay(parsed.toLocal());
    final dayStart = _startOfDay(day);
    if (dayStart.isBefore(start)) return false;
    if (durationDays != null && durationDays > 0) {
      final end = _endOfDay(start.add(Duration(days: durationDays - 1)));
      if (day.isAfter(end)) return false;
    }
    return true;
  }

  /// Lazily create pending dose logs for a given day for all active meds.
  Future<void> ensureDoseLogsForDay(int patientId, [DateTime? forDay]) async {
    final day = forDay ?? DateTime.now();
    final database = await AppDatabase.instance.db;

    final presRows = await database.query(
      'prescriptions',
      columns: ['id'],
      where: 'patient_id = ? AND status = ?',
      whereArgs: [patientId, 'active'],
    );
    final presIds = presRows.map((p) => p['id'] as int).toList();
    if (presIds.isEmpty) return;

    final presPlaceholders = List.filled(presIds.length, '?').join(',');
    final medRows = await database.query(
      'medications',
      where: 'prescription_id IN ($presPlaceholders)',
      whereArgs: presIds,
    );
    if (medRows.isEmpty) return;
    final meds = medRows.map(Medication.fromMap).toList();

    final medIds = meds.map((m) => m.id).toList();
    final medPlaceholders = List.filled(medIds.length, '?').join(',');
    final timeRows = await database.query(
      'schedule_times',
      where: 'medication_id IN ($medPlaceholders)',
      whereArgs: medIds,
    );
    final times = timeRows.map(ScheduleTime.fromMap).toList();

    final dayStart = _iso(_startOfDay(day));
    final dayEnd = _iso(_endOfDay(day));
    final existingRows = await database.query(
      'dose_logs',
      where: 'scheduled_at >= ? AND scheduled_at <= ?',
      whereArgs: [dayStart, dayEnd],
    );
    final existingKeys = existingRows
        .map((e) => '${e['medication_id']}-${e['schedule_time_id']}')
        .toSet();

    for (final t in times) {
      Medication? med;
      for (final m in meds) {
        if (m.id == t.medicationId) {
          med = m;
          break;
        }
      }
      if (med == null) continue;
      if (!_withinMedicationWindow(med.startDate, med.durationDays, day)) {
        continue;
      }
      final key = '${t.medicationId}-${t.id}';
      if (existingKeys.contains(key)) continue;

      await database.insert('dose_logs', {
        'medication_id': t.medicationId,
        'schedule_time_id': t.id,
        'scheduled_at': _iso(dateAtTime(day, t.time)),
        'status': 'pending',
        'quantity': t.doseAmount,
      });
    }
  }

  Future<List<TodayDose>> getDosesForDay(int patientId, [DateTime? forDay]) async {
    final day = forDay ?? DateTime.now();
    await ensureDoseLogsForDay(patientId, day);
    final database = await AppDatabase.instance.db;

    final rows = await database.rawQuery(
      '''
SELECT d.id, d.medication_id, d.scheduled_at, d.status, d.quantity,
       m.name AS medication_name, m.form, m.dosage,
       m.relation_to_meal, m.take_with, m.image_uri
FROM dose_logs d
INNER JOIN medications m ON d.medication_id = m.id
WHERE d.scheduled_at >= ? AND d.scheduled_at <= ?
''',
      [_iso(_startOfDay(day)), _iso(_endOfDay(day))],
    );

    final doses = rows.map((r) {
      final scheduledAt = r['scheduled_at'] as String;
      return TodayDose(
        id: r['id'] as int,
        medicationId: r['medication_id'] as int,
        medicationName: r['medication_name'] as String,
        form: r['form'] as String?,
        dosage: r['dosage'] as String?,
        relationToMeal: r['relation_to_meal'] as String?,
        takeWith: r['take_with'] as String?,
        imageUri: r['image_uri'] as String?,
        scheduledAt: scheduledAt,
        time: _hhmm(scheduledAt),
        status: doseStatusFromString(r['status'] as String?),
        doseAmount: (r['quantity'] as num?)?.toDouble() ?? 1,
      );
    }).toList();

    doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return doses;
  }

  Future<void> markDose(int doseLogId, DoseStatus status) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'dose_logs',
      where: 'id = ?',
      whereArgs: [doseLogId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final log = DoseLog.fromMap(rows.first);

    final wasTaken = log.status == 'taken';
    await database.update(
      'dose_logs',
      {
        'status': doseStatusToString(status),
        'taken_at': status == DoseStatus.taken ? nowIso() : null,
      },
      where: 'id = ?',
      whereArgs: [doseLogId],
    );

    // Adjust stock: deduct when newly taken, restore when un-taking.
    final amount = log.quantity ?? 1;
    if (status == DoseStatus.taken && !wasTaken) {
      await prescriptions.adjustMedicationStock(log.medicationId, -amount);
    } else if (status != DoseStatus.taken && wasTaken) {
      await prescriptions.adjustMedicationStock(log.medicationId, amount);
    }
  }

  Future<List<int>> _medicationIdsForPatient(int patientId) async {
    final database = await AppDatabase.instance.db;
    final presRows = await database.query(
      'prescriptions',
      columns: ['id'],
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
    final presIds = presRows.map((p) => p['id'] as int).toList();
    if (presIds.isEmpty) return [];

    final placeholders = List.filled(presIds.length, '?').join(',');
    final medRows = await database.query(
      'medications',
      columns: ['id'],
      where: 'prescription_id IN ($placeholders)',
      whereArgs: presIds,
    );
    return medRows.map((m) => m['id'] as int).toList();
  }

  /// Full dose history over the past [days], grouped by day (newest first).
  /// Only includes doses whose scheduled time has already passed.
  Future<List<HistoryDay>> getDoseHistory(int patientId, {int days = 30}) async {
    final start = _startOfDay(DateTime.now().subtract(Duration(days: days - 1)));
    for (var i = 0; i < days; i++) {
      await ensureDoseLogsForDay(patientId, start.add(Duration(days: i)));
    }

    final medIds = await _medicationIdsForPatient(patientId);
    if (medIds.isEmpty) return [];

    final database = await AppDatabase.instance.db;
    final placeholders = List.filled(medIds.length, '?').join(',');
    final rows = await database.rawQuery(
      '''
SELECT d.id, d.scheduled_at, d.status, d.taken_at, m.name AS medication_name
FROM dose_logs d
INNER JOIN medications m ON d.medication_id = m.id
WHERE d.medication_id IN ($placeholders)
  AND d.scheduled_at >= ? AND d.scheduled_at <= ?
''',
      [...medIds, _iso(start), _iso(DateTime.now())],
    );

    final byDay = <String, List<HistoryDose>>{};
    for (final r in rows) {
      final scheduledAt = r['scheduled_at'] as String;
      final rawStatus = r['status'] as String?;
      final dose = HistoryDose(
        id: r['id'] as int,
        medicationName: r['medication_name'] as String,
        scheduledAt: scheduledAt,
        time: _hhmm(scheduledAt),
        // A pending dose whose time has passed counts as missed in history.
        status: rawStatus == 'pending'
            ? DoseStatus.missed
            : doseStatusFromString(rawStatus),
        takenAt: r['taken_at'] as String?,
      );
      byDay.putIfAbsent(_ymd(scheduledAt), () => []).add(dose);
    }

    final result = byDay.entries.map((e) {
      final doses = e.value..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      return HistoryDay(
        date: e.key,
        doses: doses,
        taken: doses.where((d) => d.status == DoseStatus.taken).length,
        total: doses.length,
      );
    }).toList();

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<AdherenceStat> getAdherence(int patientId, {int days = 7}) async {
    final start = _startOfDay(DateTime.now().subtract(Duration(days: days - 1)));
    for (var i = 0; i < days; i++) {
      await ensureDoseLogsForDay(patientId, start.add(Duration(days: i)));
    }

    final medIds = await _medicationIdsForPatient(patientId);
    if (medIds.isEmpty) {
      return const AdherenceStat(taken: 0, total: 0, ratio: 1);
    }

    final database = await AppDatabase.instance.db;
    final placeholders = List.filled(medIds.length, '?').join(',');
    final rows = await database.query(
      'dose_logs',
      where: 'medication_id IN ($placeholders) '
          'AND scheduled_at >= ? AND scheduled_at <= ?',
      whereArgs: [...medIds, _iso(start), _iso(_endOfDay(DateTime.now()))],
    );

    // Only count doses already due — a dose later today is not a miss yet.
    final now = DateTime.now();
    final due = rows.where((r) {
      final at = DateTime.tryParse(r['scheduled_at'] as String)?.toLocal();
      if (at == null) return false;
      return at.isBefore(now) ||
          (at.year == now.year && at.month == now.month && at.day == now.day);
    }).toList();

    final total = due.length;
    final taken = due.where((r) => r['status'] == 'taken').length;
    return AdherenceStat(
      taken: taken,
      total: total,
      ratio: total == 0 ? 1 : taken / total,
    );
  }
}
