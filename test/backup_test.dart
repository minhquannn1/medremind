import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/db/database.dart';
import 'package:medremind/db/repositories/appointments_repository.dart';
import 'package:medremind/db/repositories/backup_repository.dart';
import 'package:medremind/db/repositories/doses_repository.dart';
import 'package:medremind/db/repositories/patients_repository.dart';
import 'package:medremind/db/repositories/prescriptions_repository.dart';
import 'package:medremind/db/repositories/settings_repository.dart';

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

  const patients = PatientsRepository();
  const prescriptions = PrescriptionsRepository();
  const appointments = AppointmentsRepository();
  const backup = BackupRepository();
  const settings = SettingsRepository();

  group('AppointmentsRepository', () {
    test('creates and lists all appointments in date order', () async {
      final patientId = await patients.createPatient(fullName: 'P');
      final later = DateTime.now().add(const Duration(days: 5));
      final sooner = DateTime.now().add(const Duration(days: 1));

      await appointments.createAppointment(
        patientId: patientId,
        type: 'revisit',
        date: later.toUtc().toIso8601String(),
      );
      await appointments.createAppointment(
        patientId: patientId,
        type: 'refill',
        date: sooner.toUtc().toIso8601String(),
        note: 'mua thuoc',
      );

      final all = await appointments.listAllAppointments(patientId);
      expect(all.length, 2);
      expect(all.first.type, 'refill', reason: 'sorted by date ascending');
      expect(all.first.note, 'mua thuoc');
    });

    test('upcoming excludes past appointments', () async {
      final patientId = await patients.createPatient(fullName: 'P');
      await appointments.createAppointment(
        patientId: patientId,
        type: 'revisit',
        date: DateTime.now()
            .subtract(const Duration(days: 10))
            .toUtc()
            .toIso8601String(),
      );
      await appointments.createAppointment(
        patientId: patientId,
        type: 'revisit',
        date:
            DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(),
      );

      final upcoming = await appointments.listUpcomingAppointments(patientId);
      expect(upcoming.length, 1);
    });

    test('listAppointmentsForDay returns only that calendar day', () async {
      final patientId = await patients.createPatient(fullName: 'P');
      final today = DateTime.now();
      await appointments.createAppointment(
        patientId: patientId,
        type: 'revisit',
        date: DateTime(today.year, today.month, today.day, 10)
            .toUtc()
            .toIso8601String(),
      );
      await appointments.createAppointment(
        patientId: patientId,
        type: 'revisit',
        date: DateTime(today.year, today.month, today.day, 10)
            .add(const Duration(days: 2))
            .toUtc()
            .toIso8601String(),
      );

      final onDay = await appointments.listAppointmentsForDay(patientId, today);
      expect(onDay.length, 1);
    });

    test('deletes an appointment', () async {
      final patientId = await patients.createPatient(fullName: 'P');
      final id = await appointments.createAppointment(
        patientId: patientId,
        type: 'refill',
        date: DateTime.now().toUtc().toIso8601String(),
      );
      await appointments.deleteAppointment(id);
      expect(await appointments.listAllAppointments(patientId), isEmpty);
    });
  });

  group('BackupRepository export/import', () {
    Future<int> seedFullProfile() async {
      final patientId = await patients.createPatient(
        fullName: 'Nguyen Van A',
        dob: '1990-05-20',
        gender: 'male',
        heightCm: 170,
        weightKg: 65,
      );
      await patients.addCondition(patientId, 'Tang huyet ap');
      await patients.addAllergy(patientId, 'Penicillin', severity: 'severe');
      await prescriptions.createPrescription(PrescriptionInput(
        patientId: patientId,
        doctorName: 'BS Nguyen',
        clinic: 'BV Bach Mai',
        medications: const [
          MedicationInput(
            name: 'Amlodipin 5mg',
            dosage: '1 vien',
            quantityTotal: 30,
            times: [MedicationTimeInput(time: '08:00')],
          ),
        ],
      ));
      await appointments.createAppointment(
        patientId: patientId,
        type: 'revisit',
        date:
            DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
      );
      await settings.set(SettingsKeys.doctorPairCode, 'MED-ABC123');
      await settings.set(SettingsKeys.doctorName, 'BS Nguyen');
      return patientId;
    }

    test('exports every table for the patient', () async {
      final patientId = await seedFullProfile();
      await const DosesRepository().getDosesForDay(patientId);

      final export = await backup.exportPatientData(patientId);
      expect(export, isNotNull);
      expect(export!.version, backupVersion);
      expect(export.patient.fullName, 'Nguyen Van A');
      expect(export.conditions.single.name, 'Tang huyet ap');
      expect(export.allergies.single.substance, 'Penicillin');
      expect(export.prescriptions.single.doctorName, 'BS Nguyen');
      expect(export.medications.single.name, 'Amlodipin 5mg');
      expect(export.scheduleTimes.single.time, '08:00');
      expect(export.doseLogs, isNotEmpty);
      expect(export.appointments.single.type, 'revisit');
      expect(export.settings.doctorPairCode, 'MED-ABC123');
    });

    test('returns null for a patient that does not exist', () async {
      expect(await backup.exportPatientData(4242), isNull);
    });

    test('survives a full JSON round-trip and re-imports onto a clean device',
        () async {
      final patientId = await seedFullProfile();
      final export = await backup.exportPatientData(patientId);

      // Serialize exactly like the app uploads it, then parse it back.
      final wire = jsonDecode(jsonEncode(export!.toJson()))
          as Map<String, Object?>;
      final parsed = PatientDataExport.fromJson(wire);
      expect(parsed, isNotNull);

      // Simulate a clean device.
      await AppDatabase.instance.close();
      await AppDatabase.instance.openInMemory();

      final newId = await backup.importPatientData(parsed!, 77, 'a@b.com');
      final restored = await patients.getPatient(newId);
      expect(restored!.fullName, 'Nguyen Van A');
      expect(restored.accountUserId, 77);
      expect(restored.heightCm, 170);

      expect((await patients.listConditions(newId)).single.name,
          'Tang huyet ap');
      expect((await patients.listAllergies(newId)).single.substance,
          'Penicillin');

      final pres = await prescriptions.listPrescriptions(newId);
      expect(pres.single.clinic, 'BV Bach Mai');

      final meds = await prescriptions.listMedications(pres.single.id);
      expect(meds.single.name, 'Amlodipin 5mg');
      expect(meds.single.quantityTotal, 30);

      final times = await prescriptions.listScheduleTimes(meds.single.id);
      expect(times.single.time, '08:00',
          reason: 'schedule must survive the id remap');

      expect((await appointments.listAllAppointments(newId)).single.type,
          'revisit');
      expect(await settings.get(SettingsKeys.doctorPairCode), 'MED-ABC123');
    });

    test('import remaps ids so restored rows link to the new patient',
        () async {
      final patientId = await seedFullProfile();
      final export = await backup.exportPatientData(patientId);

      // Import into the SAME database — ids must not collide with existing rows.
      final newId = await backup.importPatientData(export!, 88, 'c@d.com');
      expect(newId, isNot(patientId));

      final pres = await prescriptions.listPrescriptions(newId);
      expect(pres.single.patientId, newId);

      final meds = await prescriptions.listMedications(pres.single.id);
      expect(meds.single.prescriptionId, pres.single.id);

      // The original profile is untouched.
      expect((await prescriptions.listPrescriptions(patientId)).length, 1);
    });

    test('device-local file paths are dropped on import', () async {
      final patientId = await patients.createPatient(fullName: 'P');
      final presId = await prescriptions.createPrescription(PrescriptionInput(
        patientId: patientId,
        imageUri: 'file:///old/device/scan.jpg',
        medications: const [MedicationInput(name: 'M')],
      ));
      final medId = (await prescriptions.listMedications(presId)).single.id;
      await prescriptions.updateMedicationImage(medId, 'file:///old/pill.jpg');

      final export = await backup.exportPatientData(patientId);
      final newId = await backup.importPatientData(export!, 5, 'e@f.com');

      final newPres = (await prescriptions.listPrescriptions(newId)).single;
      final newMed = (await prescriptions.listMedications(newPres.id)).single;
      expect(newPres.imageUri, isNull,
          reason: 'a path from another device would render as a broken image');
      expect(newMed.imageUri, isNull);
    });

    test('rejects a corrupt blob instead of importing garbage', () {
      expect(PatientDataExport.fromJson(const {}), isNull);
      expect(PatientDataExport.fromJson(const {'patient': 'not-an-object'}),
          isNull);
      expect(
        PatientDataExport.fromJson(const {'patient': <String, Object?>{}}),
        isNull,
        reason: 'missing prescriptions list',
      );
    });

    test('parses a backup produced by the React Native app', () {
      // Exact camelCase shape the RN app uploads (Drizzle row serialisation).
      const rnBackup = '''
{
  "version": 1,
  "exportedAt": "2026-07-20T10:00:00.000Z",
  "patient": {
    "id": 1, "fullName": "RN User", "dob": "1985-03-10", "gender": "female",
    "heightCm": 158, "weightKg": 52, "accountUserId": 9,
    "accountEmail": "rn@user.vn", "createdAt": "2026-01-01T00:00:00.000Z"
  },
  "conditions": [
    {"id": 1, "patientId": 1, "name": "Dai thao duong",
     "note": "type 2", "createdAt": "2026-01-01T00:00:00.000Z"}
  ],
  "allergies": [
    {"id": 1, "patientId": 1, "substance": "Aspirin", "severity": "mild",
     "reaction": "phat ban", "createdAt": "2026-01-01T00:00:00.000Z"}
  ],
  "prescriptions": [
    {"id": 3, "patientId": 1, "doctorName": "BS Tran", "clinic": "Cho Ray",
     "issuedDate": "2026-07-01", "notes": null, "imageUri": null,
     "status": "active", "createdAt": "2026-07-01T00:00:00.000Z"}
  ],
  "medications": [
    {"id": 4, "prescriptionId": 3, "name": "Metformin 500mg", "form": "tablet",
     "dosage": "1 vien", "relationToMeal": "after", "takeWith": "nhieu nuoc",
     "durationDays": 30, "startDate": "2026-07-01", "quantityTotal": 60,
     "quantityRemaining": 45, "notes": null, "explanation": "Ha duong huyet.",
     "explanationLang": "vi", "imageUri": null,
     "createdAt": "2026-07-01T00:00:00.000Z"}
  ],
  "scheduleTimes": [
    {"id": 7, "medicationId": 4, "time": "07:30", "doseAmount": 1},
    {"id": 8, "medicationId": 4, "time": "19:30", "doseAmount": 1}
  ],
  "doseLogs": [
    {"id": 11, "medicationId": 4, "scheduleTimeId": 7,
     "scheduledAt": "2026-07-19T00:30:00.000Z", "status": "taken",
     "takenAt": "2026-07-19T00:35:00.000Z", "quantity": 1}
  ],
  "appointments": [
    {"id": 2, "patientId": 1, "type": "revisit", "date": "2026-08-01T02:00:00.000Z",
     "note": "tai kham", "notificationId": "abc", "createdAt": "2026-07-01T00:00:00.000Z"}
  ],
  "settings": {
    "doctorPairCode": "MED-RN0001", "doctorName": "BS Tran",
    "reminderSound": "true", "reminderVibration": "false"
  }
}
''';
      final parsed = PatientDataExport.fromJson(
        jsonDecode(rnBackup) as Map<String, Object?>,
      );

      expect(parsed, isNotNull, reason: 'RN backups must be readable');
      expect(parsed!.patient.fullName, 'RN User');
      expect(parsed.patient.heightCm, 158);
      expect(parsed.medications.single.explanation, 'Ha duong huyet.');
      expect(parsed.medications.single.quantityRemaining, 45);
      expect(parsed.scheduleTimes.length, 2);
      expect(parsed.doseLogs.single.status, 'taken');
      expect(parsed.appointments.single.note, 'tai kham');
      expect(parsed.settings.doctorPairCode, 'MED-RN0001');
      expect(parsed.settings.reminderVibration, 'false');
    });

    test('restores an RN backup end to end', () async {
      const rnBackup = '''
{
  "version": 1, "exportedAt": "2026-07-20T10:00:00.000Z",
  "patient": {"id": 1, "fullName": "RN User", "createdAt": "2026-01-01T00:00:00.000Z"},
  "conditions": [], "allergies": [],
  "prescriptions": [{"id": 3, "patientId": 1, "status": "active",
    "createdAt": "2026-07-01T00:00:00.000Z"}],
  "medications": [{"id": 4, "prescriptionId": 3, "name": "Metformin 500mg",
    "quantityTotal": 60, "quantityRemaining": 45,
    "createdAt": "2026-07-01T00:00:00.000Z"}],
  "scheduleTimes": [{"id": 7, "medicationId": 4, "time": "07:30", "doseAmount": 1}],
  "doseLogs": [], "appointments": [],
  "settings": {"doctorPairCode": null, "doctorName": null,
    "reminderSound": null, "reminderVibration": null}
}
''';
      final parsed = PatientDataExport.fromJson(
        jsonDecode(rnBackup) as Map<String, Object?>,
      )!;

      final newId = await backup.importPatientData(parsed, 12, 'rn@user.vn');
      final pres = await prescriptions.listPrescriptions(newId);
      final meds = await prescriptions.listMedications(pres.single.id);
      final times = await prescriptions.listScheduleTimes(meds.single.id);

      expect((await patients.getPatient(newId))!.fullName, 'RN User');
      expect(meds.single.name, 'Metformin 500mg');
      expect(meds.single.quantityRemaining, 45);
      expect(times.single.time, '07:30');
    });
  });

  group('BackupRepository.deleteLocalPatientData', () {
    test('wipes every table for that patient and clears the doctor link',
        () async {
      final patientId = await patients.createPatient(fullName: 'P');
      await patients.addCondition(patientId, 'C');
      await patients.addAllergy(patientId, 'A');
      final presId = await prescriptions.createPrescription(PrescriptionInput(
        patientId: patientId,
        medications: const [
          MedicationInput(name: 'M', times: [MedicationTimeInput(time: '08:00')]),
        ],
      ));
      final medId = (await prescriptions.listMedications(presId)).single.id;
      await const DosesRepository().getDosesForDay(patientId);
      await appointments.createAppointment(
        patientId: patientId,
        type: 'refill',
        date: DateTime.now().toUtc().toIso8601String(),
      );
      await settings.set(SettingsKeys.doctorPairCode, 'MED-XYZ');

      await backup.deleteLocalPatientData(patientId);

      expect(await patients.getPatient(patientId), isNull);
      expect(await patients.listConditions(patientId), isEmpty);
      expect(await patients.listAllergies(patientId), isEmpty);
      expect(await prescriptions.listPrescriptions(patientId), isEmpty);
      expect(await prescriptions.listMedications(presId), isEmpty);
      expect(await prescriptions.listScheduleTimes(medId), isEmpty);
      expect(await appointments.listAllAppointments(patientId), isEmpty);
      expect(await settings.get(SettingsKeys.doctorPairCode), '');

      final database = await AppDatabase.instance.db;
      final doses = await database.query('dose_logs');
      expect(doses, isEmpty, reason: 'dose history must go too');
    });

    test('leaves another patient untouched', () async {
      final a = await patients.createPatient(fullName: 'A');
      final b = await patients.createPatient(fullName: 'B');
      await prescriptions.createPrescription(PrescriptionInput(patientId: b));

      await backup.deleteLocalPatientData(a);

      expect(await patients.getPatient(b), isNotNull);
      expect((await prescriptions.listPrescriptions(b)).length, 1);
    });

    test('deleting a patient with no data does not throw', () async {
      final id = await patients.createPatient(fullName: 'Empty');
      await expectLater(backup.deleteLocalPatientData(id), completes);
      expect(await patients.getPatient(id), isNull);
    });
  });
}
