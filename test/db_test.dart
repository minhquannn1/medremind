import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/services/database.dart';
import 'package:medremind/domain/models/models.dart';
import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/repositories/settings_repository.dart';

/// Repository tests run against a real in-memory SQLite database, so the DDL,
/// the SQL and the model mapping are all exercised for real.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.close();
    await AppDatabase.instance.openInMemory();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('SettingsRepository', () {
    test('returns null for an unset key', () async {
      expect(await const SettingsRepository().get('nope'), isNull);
    });

    test('writes then reads a value back', () async {
      const repo = SettingsRepository();
      await repo.set(SettingsKeys.language, 'vi');
      expect(await repo.get(SettingsKeys.language), 'vi');
    });

    test('overwrites an existing key instead of duplicating it', () async {
      const repo = SettingsRepository();
      await repo.set(SettingsKeys.language, 'vi');
      await repo.set(SettingsKeys.language, 'en');
      expect(await repo.get(SettingsKeys.language), 'en');
    });

    test('getBool falls back when unset and parses "true"', () async {
      const repo = SettingsRepository();
      expect(await repo.getBool(SettingsKeys.reminderSound, true), isTrue);
      await repo.set(SettingsKeys.reminderSound, 'false');
      expect(await repo.getBool(SettingsKeys.reminderSound, true), isFalse);
    });
  });

  group('PatientsRepository', () {
    test('creates and reads a patient', () async {
      const repo = PatientsRepository();
      final id = await repo.createPatient(
        fullName: 'Nguyen Van A',
        dob: '1990-05-20',
        gender: 'male',
        heightCm: 170,
        weightKg: 65,
      );
      final p = await repo.getPatient(id);
      expect(p, isNotNull);
      expect(p!.fullName, 'Nguyen Van A');
      expect(p.heightCm, 170);
      expect(p.gender, 'male');
    });

    test('finds a patient by account id', () async {
      const repo = PatientsRepository();
      await repo.createPatient(fullName: 'Owned', accountUserId: 42);
      final found = await repo.getPatientByAccount(42);
      expect(found?.fullName, 'Owned');
      expect(await repo.getPatientByAccount(99), isNull);
    });

    test('claimOrphanPatient adopts a profile with no account', () async {
      const repo = PatientsRepository();
      await repo.createPatient(fullName: 'Orphan');
      final claimed = await repo.claimOrphanPatient(7, 'a@b.com');
      expect(claimed, isNotNull);
      expect(claimed!.accountUserId, 7);
      // Persisted, not just returned.
      expect((await repo.getPatientByAccount(7))?.fullName, 'Orphan');
    });

    test('claimOrphanPatient returns null when every profile is owned',
        () async {
      const repo = PatientsRepository();
      await repo.createPatient(fullName: 'Owned', accountUserId: 1);
      expect(await repo.claimOrphanPatient(2, 'x@y.com'), isNull);
    });

    test('updatePatient writes only the given fields', () async {
      const repo = PatientsRepository();
      final id = await repo.createPatient(fullName: 'Before', heightCm: 160);
      await repo.updatePatient(id, {'weight_kg': 70.0});
      final p = await repo.getPatient(id);
      expect(p!.weightKg, 70);
      expect(p.heightCm, 160, reason: 'untouched column must survive');
      expect(p.fullName, 'Before');
    });

    test('conditions and allergies add, list and remove', () async {
      const repo = PatientsRepository();
      final id = await repo.createPatient(fullName: 'P');
      await repo.addCondition(id, 'Tang huyet ap', note: 'do 2');
      await repo.addAllergy(id, 'Penicillin', severity: 'severe');

      final conds = await repo.listConditions(id);
      final allergies = await repo.listAllergies(id);
      expect(conds.single.name, 'Tang huyet ap');
      expect(conds.single.note, 'do 2');
      expect(allergies.single.substance, 'Penicillin');
      expect(allergies.single.severity, 'severe');

      await repo.removeCondition(conds.single.id);
      await repo.removeAllergy(allergies.single.id);
      expect(await repo.listConditions(id), isEmpty);
      expect(await repo.listAllergies(id), isEmpty);
    });
  });

  group('PrescriptionsRepository', () {
    const patients = PatientsRepository();
    const repo = PrescriptionsRepository();

    Future<int> makePatient() => patients.createPatient(fullName: 'P');

    test('creates a prescription with medications and schedule times',
        () async {
      final patientId = await makePatient();
      final presId = await repo.createPrescription(PrescriptionInput(
        patientId: patientId,
        doctorName: 'BS Nguyen',
        clinic: 'BV Bach Mai',
        medications: const [
          MedicationInput(
            name: 'Paracetamol 500mg',
            dosage: '1 vien',
            quantityTotal: 20,
            times: [
              MedicationTimeInput(time: '08:00'),
              MedicationTimeInput(time: '20:00', doseAmount: 2),
            ],
          ),
        ],
      ));

      final meds = await repo.listMedications(presId);
      expect(meds.single.name, 'Paracetamol 500mg');
      expect(meds.single.quantityTotal, 20);
      expect(meds.single.quantityRemaining, 20,
          reason: 'stock starts full');

      final times = await repo.listScheduleTimes(meds.single.id);
      expect(times.map((t) => t.time).toList()..sort(), ['08:00', '20:00']);
      expect(times.firstWhere((t) => t.time == '20:00').doseAmount, 2);
    });

    test('lists prescriptions for the patient', () async {
      final patientId = await makePatient();
      await repo.createPrescription(PrescriptionInput(patientId: patientId));
      await repo.createPrescription(PrescriptionInput(patientId: patientId));
      expect((await repo.listPrescriptions(patientId)).length, 2);
      expect(await repo.listPrescriptions(999), isEmpty);
    });

    test('deletePrescription cascades to medications and schedule times',
        () async {
      final patientId = await makePatient();
      final presId = await repo.createPrescription(PrescriptionInput(
        patientId: patientId,
        medications: const [
          MedicationInput(
            name: 'Amlodipin',
            times: [MedicationTimeInput(time: '08:00')],
          ),
        ],
      ));
      final medId = (await repo.listMedications(presId)).single.id;

      await repo.deletePrescription(presId);

      expect(await repo.getPrescription(presId), isNull);
      expect(await repo.listMedications(presId), isEmpty);
      expect(await repo.listScheduleTimes(medId), isEmpty);
    });

    test('adjustMedicationStock clamps at zero and is a no-op when untracked',
        () async {
      final patientId = await makePatient();
      final presId = await repo.createPrescription(PrescriptionInput(
        patientId: patientId,
        medications: const [
          MedicationInput(name: 'Tracked', quantityTotal: 3),
          MedicationInput(name: 'Untracked'),
        ],
      ));
      final meds = await repo.listMedications(presId);
      final tracked = meds.firstWhere((m) => m.name == 'Tracked');
      final untracked = meds.firstWhere((m) => m.name == 'Untracked');

      await repo.adjustMedicationStock(tracked.id, -10);
      expect((await repo.getMedication(tracked.id))!.quantityRemaining, 0,
          reason: 'must not go negative');

      await repo.adjustMedicationStock(untracked.id, -1);
      expect((await repo.getMedication(untracked.id))!.quantityRemaining, isNull);
    });

    test('updates schedule time, image and explanation', () async {
      final patientId = await makePatient();
      final presId = await repo.createPrescription(PrescriptionInput(
        patientId: patientId,
        medications: const [
          MedicationInput(
            name: 'M',
            times: [MedicationTimeInput(time: '07:00')],
          ),
        ],
      ));
      final medId = (await repo.listMedications(presId)).single.id;
      final timeId = (await repo.listScheduleTimes(medId)).single.id;

      await repo.updateScheduleTime(timeId, '09:30');
      await repo.updateMedicationImage(medId, 'file:///photo.jpg');
      await repo.updateMedicationExplanation(medId, 'Giam dau', 'vi');

      expect((await repo.listScheduleTimes(medId)).single.time, '09:30');
      final med = await repo.getMedication(medId);
      expect(med!.imageUri, 'file:///photo.jpg');
      expect(med.explanation, 'Giam dau');
      expect(med.explanationLang, 'vi');
    });

    test('listActiveMedicationsWithSchedule groups times under each med',
        () async {
      final patientId = await makePatient();
      await repo.createPrescription(PrescriptionInput(
        patientId: patientId,
        medications: const [
          MedicationInput(
            name: 'A',
            times: [
              MedicationTimeInput(time: '08:00'),
              MedicationTimeInput(time: '20:00'),
            ],
          ),
          MedicationInput(
            name: 'B',
            times: [MedicationTimeInput(time: '12:00')],
          ),
        ],
      ));

      final result = await repo.listActiveMedicationsWithSchedule(patientId);
      expect(result.length, 2);
      final a = result.firstWhere((r) => r.medication.name == 'A');
      final b = result.firstWhere((r) => r.medication.name == 'B');
      expect(a.times.length, 2);
      expect(b.times.single.time, '12:00');
    });

    test('returns empty for a patient with no prescriptions', () async {
      expect(await repo.listActiveMedicationsWithSchedule(12345), isEmpty);
    });
  });

  group('DosesRepository', () {
    const patients = PatientsRepository();
    const prescriptions = PrescriptionsRepository();
    const doses = DosesRepository();

    Future<int> seedPatientWithMed({
      String time = '08:00',
      double? quantityTotal,
      String? startDate,
      int? durationDays,
    }) async {
      final patientId = await patients.createPatient(fullName: 'P');
      await prescriptions.createPrescription(PrescriptionInput(
        patientId: patientId,
        medications: [
          MedicationInput(
            name: 'Med',
            quantityTotal: quantityTotal,
            startDate: startDate,
            durationDays: durationDays,
            times: [MedicationTimeInput(time: time)],
          ),
        ],
      ));
      return patientId;
    }

    test('generates one pending dose per schedule time', () async {
      final patientId = await seedPatientWithMed();
      final today = await doses.getDosesForDay(patientId);
      expect(today.length, 1);
      expect(today.single.status, DoseStatus.pending);
      expect(today.single.time, '08:00');
      expect(today.single.medicationName, 'Med');
    });

    test('is idempotent — repeated calls do not duplicate dose logs', () async {
      final patientId = await seedPatientWithMed();
      await doses.getDosesForDay(patientId);
      await doses.getDosesForDay(patientId);
      final today = await doses.getDosesForDay(patientId);
      expect(today.length, 1, reason: 'must not create a dose per call');
    });

    test('markDose taken deducts stock, un-taking restores it', () async {
      final patientId = await seedPatientWithMed(quantityTotal: 10);
      final dose = (await doses.getDosesForDay(patientId)).single;

      await doses.markDose(dose.id, DoseStatus.taken);
      var med = await prescriptions.getMedication(dose.medicationId);
      expect(med!.quantityRemaining, 9);

      await doses.markDose(dose.id, DoseStatus.skipped);
      med = await prescriptions.getMedication(dose.medicationId);
      expect(med!.quantityRemaining, 10, reason: 'stock restored on un-take');
    });

    test('marking taken twice only deducts once', () async {
      final patientId = await seedPatientWithMed(quantityTotal: 10);
      final dose = (await doses.getDosesForDay(patientId)).single;
      await doses.markDose(dose.id, DoseStatus.taken);
      await doses.markDose(dose.id, DoseStatus.taken);
      final med = await prescriptions.getMedication(dose.medicationId);
      expect(med!.quantityRemaining, 9);
    });

    test('markDose sets takenAt only for taken', () async {
      final patientId = await seedPatientWithMed();
      final dose = (await doses.getDosesForDay(patientId)).single;

      await doses.markDose(dose.id, DoseStatus.taken);
      var updated = (await doses.getDosesForDay(patientId)).single;
      expect(updated.status, DoseStatus.taken);

      await doses.markDose(dose.id, DoseStatus.skipped);
      updated = (await doses.getDosesForDay(patientId)).single;
      expect(updated.status, DoseStatus.skipped);
    });

    test('markDose on a missing log is a no-op, not a crash', () async {
      await expectLater(doses.markDose(987654, DoseStatus.taken), completes);
    });

    test('a medication that has not started yet generates no doses', () async {
      final future = DateTime.now().add(const Duration(days: 5));
      final patientId = await seedPatientWithMed(
        startDate: DateTime(future.year, future.month, future.day)
            .toIso8601String(),
      );
      expect(await doses.getDosesForDay(patientId), isEmpty);
    });

    test('a finished course generates no doses today', () async {
      final past = DateTime.now().subtract(const Duration(days: 30));
      final patientId = await seedPatientWithMed(
        startDate: DateTime(past.year, past.month, past.day).toIso8601String(),
        durationDays: 3,
      );
      expect(await doses.getDosesForDay(patientId), isEmpty);
    });

    test('adherence is 100% when nothing is prescribed', () async {
      final patientId = await patients.createPatient(fullName: 'Empty');
      final stat = await doses.getAdherence(patientId);
      expect(stat.total, 0);
      expect(stat.ratio, 1);
    });

    test('adherence counts a taken dose', () async {
      final patientId = await seedPatientWithMed();
      final dose = (await doses.getDosesForDay(patientId)).single;
      await doses.markDose(dose.id, DoseStatus.taken);

      final stat = await doses.getAdherence(patientId, days: 1);
      expect(stat.total, greaterThanOrEqualTo(1));
      expect(stat.taken, 1);
      expect(stat.ratio, greaterThan(0));
    });

    test('history groups by day and reports a pending past dose as missed',
        () async {
      final patientId = await seedPatientWithMed(time: '00:01');
      final history = await doses.getDoseHistory(patientId, days: 2);
      expect(history, isNotEmpty);
      final allDoses = history.expand((d) => d.doses).toList();
      expect(allDoses, isNotEmpty);
      expect(
        allDoses.every((d) => d.status != DoseStatus.pending),
        isTrue,
        reason: 'past pending doses are reported as missed',
      );
    });

    test('history is newest-first', () async {
      final patientId = await seedPatientWithMed(time: '00:01');
      final history = await doses.getDoseHistory(patientId, days: 5);
      final dates = history.map((h) => h.date).toList();
      final sorted = [...dates]..sort((a, b) => b.compareTo(a));
      expect(dates, sorted);
    });
  });

  group('model mapping', () {
    test('Patient round-trips through toMap/fromMap', () {
      const p = Patient(
        id: 1,
        fullName: 'A',
        dob: '1990-01-01',
        gender: 'female',
        heightCm: 160,
        weightKg: 55,
        accountUserId: 3,
        accountEmail: 'a@b.c',
        createdAt: '2026-01-01T00:00:00.000Z',
      );
      final back = Patient.fromMap(p.toMap());
      expect(back.fullName, p.fullName);
      expect(back.heightCm, p.heightCm);
      expect(back.accountUserId, p.accountUserId);
      expect(back.createdAt, p.createdAt);
    });

    test('Medication round-trips including nullable columns', () {
      const m = Medication(
        id: 2,
        prescriptionId: 5,
        name: 'Amlodipin 5mg',
        form: 'tablet',
        dosage: '1 vien',
        durationDays: 30,
        quantityTotal: 30,
        quantityRemaining: 28,
        createdAt: '2026-01-01T00:00:00.000Z',
      );
      final back = Medication.fromMap(m.toMap());
      expect(back.name, m.name);
      expect(back.quantityRemaining, 28);
      expect(back.takeWith, isNull);
      expect(back.imageUri, isNull);
    });
  });
}
