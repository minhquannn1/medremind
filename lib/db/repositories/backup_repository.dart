import '../database.dart';
import '../models.dart';
import 'settings_repository.dart';

/// Full-device export / restore, and the local wipe used by account deletion.
/// Ported from `src/db/repositories/backup.ts`.
///
/// The JSON shape is shared with the React Native app through the server's
/// `/api/patient/backup` blob, so keys stay camelCase and the version number
/// matches — a user can move between the two apps without losing data.

const int backupVersion = 1;

class BackupSettings {
  final String? doctorPairCode;
  final String? doctorName;
  final String? reminderSound;
  final String? reminderVibration;

  const BackupSettings({
    this.doctorPairCode,
    this.doctorName,
    this.reminderSound,
    this.reminderVibration,
  });

  Map<String, Object?> toJson() => {
        'doctorPairCode': doctorPairCode,
        'doctorName': doctorName,
        'reminderSound': reminderSound,
        'reminderVibration': reminderVibration,
      };

  factory BackupSettings.fromJson(Map<String, Object?> j) => BackupSettings(
        doctorPairCode: j['doctorPairCode'] as String?,
        doctorName: j['doctorName'] as String?,
        reminderSound: j['reminderSound'] as String?,
        reminderVibration: j['reminderVibration'] as String?,
      );
}

class PatientDataExport {
  final int version;
  final String exportedAt;
  final Patient patient;
  final List<MedicalCondition> conditions;
  final List<Allergy> allergies;
  final List<Prescription> prescriptions;
  final List<Medication> medications;
  final List<ScheduleTime> scheduleTimes;
  final List<DoseLog> doseLogs;
  final List<Appointment> appointments;
  final BackupSettings settings;

  const PatientDataExport({
    required this.version,
    required this.exportedAt,
    required this.patient,
    required this.conditions,
    required this.allergies,
    required this.prescriptions,
    required this.medications,
    required this.scheduleTimes,
    required this.doseLogs,
    required this.appointments,
    required this.settings,
  });

  Map<String, Object?> toJson() => {
        'version': version,
        'exportedAt': exportedAt,
        'patient': patient.toJson(),
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'allergies': allergies.map((a) => a.toJson()).toList(),
        'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
        'medications': medications.map((m) => m.toJson()).toList(),
        'scheduleTimes': scheduleTimes.map((s) => s.toJson()).toList(),
        'doseLogs': doseLogs.map((d) => d.toJson()).toList(),
        'appointments': appointments.map((a) => a.toJson()).toList(),
        'settings': settings.toJson(),
      };

  static List<Map<String, Object?>> _list(Object? v) =>
      (v as List?)?.cast<Map<String, Object?>>() ?? const [];

  /// Returns null when the blob is not a usable export — the RN app applies
  /// the same guard before restoring, so a corrupt backup never wipes a device.
  static PatientDataExport? fromJson(Map<String, Object?> j) {
    final patientJson = j['patient'];
    if (patientJson is! Map) return null;
    if (j['prescriptions'] is! List) return null;

    return PatientDataExport(
      version: (j['version'] as num?)?.toInt() ?? backupVersion,
      exportedAt: (j['exportedAt'] as String?) ?? '',
      patient: Patient.fromJson(patientJson.cast<String, Object?>()),
      conditions:
          _list(j['conditions']).map(MedicalCondition.fromJson).toList(),
      allergies: _list(j['allergies']).map(Allergy.fromJson).toList(),
      prescriptions:
          _list(j['prescriptions']).map(Prescription.fromJson).toList(),
      medications: _list(j['medications']).map(Medication.fromJson).toList(),
      scheduleTimes:
          _list(j['scheduleTimes']).map(ScheduleTime.fromJson).toList(),
      doseLogs: _list(j['doseLogs']).map(DoseLog.fromJson).toList(),
      appointments: _list(j['appointments']).map(Appointment.fromJson).toList(),
      settings: BackupSettings.fromJson(
        (j['settings'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
  }
}

class BackupRepository {
  const BackupRepository({this.settings = const SettingsRepository()});

  final SettingsRepository settings;

  static String _placeholders(int n) => List.filled(n, '?').join(',');

  /// Full export of everything the app stores for one patient profile.
  Future<PatientDataExport?> exportPatientData(int patientId) async {
    final database = await AppDatabase.instance.db;

    final patientRows = await database.query(
      'patients',
      where: 'id = ?',
      whereArgs: [patientId],
      limit: 1,
    );
    if (patientRows.isEmpty) return null;
    final patient = Patient.fromMap(patientRows.first);

    final conditionRows = await database.query('medical_conditions',
        where: 'patient_id = ?', whereArgs: [patientId]);
    final allergyRows = await database
        .query('allergies', where: 'patient_id = ?', whereArgs: [patientId]);
    final prescriptionRows = await database
        .query('prescriptions', where: 'patient_id = ?', whereArgs: [patientId]);
    final appointmentRows = await database
        .query('appointments', where: 'patient_id = ?', whereArgs: [patientId]);

    final presIds =
        prescriptionRows.map((p) => p['id'] as int).toList(growable: false);
    final medicationRows = presIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await database.query(
            'medications',
            where: 'prescription_id IN (${_placeholders(presIds.length)})',
            whereArgs: presIds,
          );

    final medIds =
        medicationRows.map((m) => m['id'] as int).toList(growable: false);
    final timeRows = medIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await database.query(
            'schedule_times',
            where: 'medication_id IN (${_placeholders(medIds.length)})',
            whereArgs: medIds,
          );
    final doseRows = medIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await database.query(
            'dose_logs',
            where: 'medication_id IN (${_placeholders(medIds.length)})',
            whereArgs: medIds,
          );

    return PatientDataExport(
      version: backupVersion,
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      patient: patient,
      conditions: conditionRows.map(MedicalCondition.fromMap).toList(),
      allergies: allergyRows.map(Allergy.fromMap).toList(),
      prescriptions: prescriptionRows.map(Prescription.fromMap).toList(),
      medications: medicationRows.map(Medication.fromMap).toList(),
      scheduleTimes: timeRows.map(ScheduleTime.fromMap).toList(),
      doseLogs: doseRows.map(DoseLog.fromMap).toList(),
      appointments: appointmentRows.map(Appointment.fromMap).toList(),
      settings: BackupSettings(
        doctorPairCode: await settings.get(SettingsKeys.doctorPairCode),
        doctorName: await settings.get(SettingsKeys.doctorName),
        reminderSound: await settings.get(SettingsKeys.reminderSound),
        reminderVibration: await settings.get(SettingsKeys.reminderVibration),
      ),
    );
  }

  /// Imports a full export, remapping every row id because this device assigns
  /// fresh autoincrement ids. Intended for a fresh sign-in where no local
  /// profile exists for the account yet. Returns the new local patient id.
  Future<int> importPatientData(
    PatientDataExport data,
    int accountUserId,
    String accountEmail,
  ) async {
    final database = await AppDatabase.instance.db;

    final patientId = await database.insert('patients', {
      'full_name': data.patient.fullName,
      'dob': data.patient.dob,
      'gender': data.patient.gender,
      'height_cm': data.patient.heightCm,
      'weight_kg': data.patient.weightKg,
      'account_user_id': accountUserId,
      'account_email': accountEmail,
      'created_at': data.patient.createdAt,
    });

    for (final c in data.conditions) {
      await database.insert('medical_conditions', {
        'patient_id': patientId,
        'name': c.name,
        'note': c.note,
        'created_at': c.createdAt,
      });
    }
    for (final a in data.allergies) {
      await database.insert('allergies', {
        'patient_id': patientId,
        'substance': a.substance,
        'severity': a.severity,
        'reaction': a.reaction,
        'created_at': a.createdAt,
      });
    }

    final presIdMap = <int, int>{};
    for (final p in data.prescriptions) {
      final newId = await database.insert('prescriptions', {
        'patient_id': patientId,
        'doctor_name': p.doctorName,
        'clinic': p.clinic,
        'issued_date': p.issuedDate,
        'notes': p.notes,
        // Image files live outside the db and don't survive a device change.
        'image_uri': null,
        'status': p.status,
        'created_at': p.createdAt,
      });
      presIdMap[p.id] = newId;
    }

    final medIdMap = <int, int>{};
    for (final m in data.medications) {
      final prescriptionId = presIdMap[m.prescriptionId];
      if (prescriptionId == null) continue;
      final newId = await database.insert('medications', {
        'prescription_id': prescriptionId,
        'name': m.name,
        'form': m.form,
        'dosage': m.dosage,
        'relation_to_meal': m.relationToMeal,
        'take_with': m.takeWith,
        'duration_days': m.durationDays,
        'start_date': m.startDate,
        'quantity_total': m.quantityTotal,
        'quantity_remaining': m.quantityRemaining,
        'notes': m.notes,
        'explanation': m.explanation,
        'explanation_lang': m.explanationLang,
        // Medicine photos are device-local files.
        'image_uri': null,
        'created_at': m.createdAt,
      });
      medIdMap[m.id] = newId;
    }

    final timeIdMap = <int, int>{};
    for (final t in data.scheduleTimes) {
      final medicationId = medIdMap[t.medicationId];
      if (medicationId == null) continue;
      final newId = await database.insert('schedule_times', {
        'medication_id': medicationId,
        'time': t.time,
        'dose_amount': t.doseAmount,
      });
      timeIdMap[t.id] = newId;
    }

    for (final d in data.doseLogs) {
      final medicationId = medIdMap[d.medicationId];
      if (medicationId == null) continue;
      await database.insert('dose_logs', {
        'medication_id': medicationId,
        'schedule_time_id':
            d.scheduleTimeId == null ? null : timeIdMap[d.scheduleTimeId],
        'scheduled_at': d.scheduledAt,
        'status': d.status,
        'taken_at': d.takenAt,
        'quantity': d.quantity,
      });
    }

    for (final a in data.appointments) {
      await database.insert('appointments', {
        'patient_id': patientId,
        'type': a.type,
        'date': a.date,
        'note': a.note,
        // Notification ids are device-local; reminders are rescheduled after.
        'notification_id': null,
        'created_at': a.createdAt,
      });
    }

    final s = data.settings;
    if (s.doctorPairCode != null && s.doctorPairCode!.isNotEmpty) {
      await settings.set(SettingsKeys.doctorPairCode, s.doctorPairCode!);
      await settings.set(SettingsKeys.doctorName, s.doctorName ?? '');
    }
    if (s.reminderSound != null) {
      await settings.set(SettingsKeys.reminderSound, s.reminderSound!);
    }
    if (s.reminderVibration != null) {
      await settings.set(SettingsKeys.reminderVibration, s.reminderVibration!);
    }

    return patientId;
  }

  /// Permanently deletes everything stored on-device for one patient profile.
  /// Used by account deletion, where local health data must go away with the
  /// account instead of lingering for the next sign-in to adopt.
  Future<void> deleteLocalPatientData(int patientId) async {
    final database = await AppDatabase.instance.db;

    final presRows = await database.query('prescriptions',
        columns: ['id'], where: 'patient_id = ?', whereArgs: [patientId]);
    final presIds = presRows.map((p) => p['id'] as int).toList();

    if (presIds.isNotEmpty) {
      final medRows = await database.query(
        'medications',
        columns: ['id'],
        where: 'prescription_id IN (${_placeholders(presIds.length)})',
        whereArgs: presIds,
      );
      final medIds = medRows.map((m) => m['id'] as int).toList();

      if (medIds.isNotEmpty) {
        await database.delete('dose_logs',
            where: 'medication_id IN (${_placeholders(medIds.length)})',
            whereArgs: medIds);
        await database.delete('schedule_times',
            where: 'medication_id IN (${_placeholders(medIds.length)})',
            whereArgs: medIds);
      }
      await database.delete('medications',
          where: 'prescription_id IN (${_placeholders(presIds.length)})',
          whereArgs: presIds);
      await database.delete('prescriptions',
          where: 'id IN (${_placeholders(presIds.length)})', whereArgs: presIds);
    }

    await database
        .delete('appointments', where: 'patient_id = ?', whereArgs: [patientId]);
    await database.delete('medical_conditions',
        where: 'patient_id = ?', whereArgs: [patientId]);
    await database
        .delete('allergies', where: 'patient_id = ?', whereArgs: [patientId]);
    await database.delete('patients', where: 'id = ?', whereArgs: [patientId]);

    await settings.set(SettingsKeys.doctorPairCode, '');
    await settings.set(SettingsKeys.doctorName, '');
  }
}
