import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/domain/models/models.dart';

/// Prescriptions, their medications and schedule times.
/// Ported from `src/db/repositories/prescriptions.ts`.

class MedicationTimeInput {
  final String time; // HH:mm
  final double doseAmount;

  const MedicationTimeInput({required this.time, this.doseAmount = 1});
}

class MedicationInput {
  final String name;
  final String? form;
  final String? dosage;
  final String? relationToMeal;
  final String? takeWith;
  final int? durationDays;
  final String? startDate;
  final double? quantityTotal;
  final String? notes;
  final String? explanation;
  final String? explanationLang;
  final List<MedicationTimeInput> times;

  const MedicationInput({
    required this.name,
    this.form,
    this.dosage,
    this.relationToMeal,
    this.takeWith,
    this.durationDays,
    this.startDate,
    this.quantityTotal,
    this.notes,
    this.explanation,
    this.explanationLang,
    this.times = const [],
  });
}

class PrescriptionInput {
  final int patientId;
  final String? doctorName;
  final String? clinic;
  final String? issuedDate;
  final String? notes;
  final String? imageUri;
  final List<MedicationInput> medications;

  const PrescriptionInput({
    required this.patientId,
    this.doctorName,
    this.clinic,
    this.issuedDate,
    this.notes,
    this.imageUri,
    this.medications = const [],
  });
}

/// A medication paired with its schedule rows.
class MedicationWithSchedule {
  final Medication medication;
  final List<ScheduleTime> times;

  const MedicationWithSchedule({required this.medication, required this.times});
}

class PrescriptionsRepository {
  const PrescriptionsRepository();

  Future<int> createPrescription(PrescriptionInput input) async {
    final database = await AppDatabase.instance.db;
    final prescriptionId = await database.insert('prescriptions', {
      'patient_id': input.patientId,
      'doctor_name': input.doctorName,
      'clinic': input.clinic,
      'issued_date': input.issuedDate,
      'notes': input.notes,
      'image_uri': input.imageUri,
      'status': 'active',
      'created_at': nowIso(),
    });

    for (final med in input.medications) {
      await addMedicationToPrescription(prescriptionId, med);
    }
    return prescriptionId;
  }

  Future<int> addMedicationToPrescription(
    int prescriptionId,
    MedicationInput med,
  ) async {
    final database = await AppDatabase.instance.db;
    final medicationId = await database.insert('medications', {
      'prescription_id': prescriptionId,
      'name': med.name,
      'form': med.form,
      'dosage': med.dosage,
      'relation_to_meal': med.relationToMeal,
      'take_with': med.takeWith,
      'duration_days': med.durationDays,
      'start_date': med.startDate,
      'quantity_total': med.quantityTotal,
      // Stock starts full — mirrors the RN behaviour.
      'quantity_remaining': med.quantityTotal,
      'notes': med.notes,
      'explanation': med.explanation,
      'explanation_lang': med.explanationLang,
      'created_at': nowIso(),
    });

    for (final t in med.times) {
      await database.insert('schedule_times', {
        'medication_id': medicationId,
        'time': t.time,
        'dose_amount': t.doseAmount,
      });
    }
    return medicationId;
  }

  Future<List<Prescription>> listPrescriptions(int patientId) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'prescriptions',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Prescription.fromMap).toList();
  }

  Future<Prescription?> getPrescription(int id) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'prescriptions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Prescription.fromMap(rows.first);
  }

  Future<void> updatePrescriptionStatus(int id, String status) async {
    final database = await AppDatabase.instance.db;
    await database.update(
      'prescriptions',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePrescription(int id) async {
    final database = await AppDatabase.instance.db;
    final medRows = await database.query(
      'medications',
      columns: ['id'],
      where: 'prescription_id = ?',
      whereArgs: [id],
    );
    final medIds = medRows.map((m) => m['id'] as int).toList();
    if (medIds.isNotEmpty) {
      final placeholders = List.filled(medIds.length, '?').join(',');
      await database.delete(
        'schedule_times',
        where: 'medication_id IN ($placeholders)',
        whereArgs: medIds,
      );
      await database.delete(
        'medications',
        where: 'prescription_id = ?',
        whereArgs: [id],
      );
    }
    await database.delete('prescriptions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Medication>> listMedications(int prescriptionId) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'medications',
      where: 'prescription_id = ?',
      whereArgs: [prescriptionId],
    );
    return rows.map(Medication.fromMap).toList();
  }

  Future<Medication?> getMedication(int id) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Medication.fromMap(rows.first);
  }

  Future<List<ScheduleTime>> listScheduleTimes(int medicationId) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'schedule_times',
      where: 'medication_id = ?',
      whereArgs: [medicationId],
    );
    return rows.map(ScheduleTime.fromMap).toList();
  }

  Future<void> updateScheduleTime(int id, String time) async {
    final database = await AppDatabase.instance.db;
    await database.update(
      'schedule_times',
      {'time': time},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMedicationImage(int medicationId, String? imageUri) async {
    final database = await AppDatabase.instance.db;
    await database.update(
      'medications',
      {'image_uri': imageUri},
      where: 'id = ?',
      whereArgs: [medicationId],
    );
  }

  Future<void> updateMedicationExplanation(
    int medicationId,
    String explanation,
    String lang,
  ) async {
    final database = await AppDatabase.instance.db;
    await database.update(
      'medications',
      {'explanation': explanation, 'explanation_lang': lang},
      where: 'id = ?',
      whereArgs: [medicationId],
    );
  }

  /// Adjusts remaining stock, clamped at zero. No-op when the medication has
  /// no tracked quantity.
  Future<void> adjustMedicationStock(int medicationId, double delta) async {
    final med = await getMedication(medicationId);
    if (med == null || med.quantityRemaining == null) return;
    final next = (med.quantityRemaining! + delta).clamp(0, double.infinity);
    final database = await AppDatabase.instance.db;
    await database.update(
      'medications',
      {'quantity_remaining': next},
      where: 'id = ?',
      whereArgs: [medicationId],
    );
  }

  /// All active medications for a patient, with their schedule times.
  Future<List<MedicationWithSchedule>> listActiveMedicationsWithSchedule(
    int patientId,
  ) async {
    final database = await AppDatabase.instance.db;
    final presRows = await database.query(
      'prescriptions',
      columns: ['id'],
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
    final presIds = presRows.map((p) => p['id'] as int).toList();
    if (presIds.isEmpty) return [];

    final presPlaceholders = List.filled(presIds.length, '?').join(',');
    final medRows = await database.query(
      'medications',
      where: 'prescription_id IN ($presPlaceholders)',
      whereArgs: presIds,
    );
    if (medRows.isEmpty) return [];
    final meds = medRows.map(Medication.fromMap).toList();

    final medIds = meds.map((m) => m.id).toList();
    final medPlaceholders = List.filled(medIds.length, '?').join(',');
    final timeRows = await database.query(
      'schedule_times',
      where: 'medication_id IN ($medPlaceholders)',
      whereArgs: medIds,
    );
    final times = timeRows.map(ScheduleTime.fromMap).toList();

    return meds
        .map((med) => MedicationWithSchedule(
              medication: med,
              times: times.where((t) => t.medicationId == med.id).toList(),
            ))
        .toList();
  }
}
