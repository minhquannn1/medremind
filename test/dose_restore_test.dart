import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/database.dart';

/// The three bugs reported on the production PWA in one afternoon, pinned at
/// the repository layer where all platforms share the code.
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
  const doses = DosesRepository();

  Future<(int, int)> seed({String time = '08:00'}) async {
    final patientId = await patients.createPatient(fullName: 'T');
    await prescriptions.createPrescription(PrescriptionInput(
      patientId: patientId,
      medications: [
        MedicationInput(
          name: 'TestMed 100mg',
          times: [MedicationTimeInput(time: time)],
        ),
      ],
    ));
    final database = await AppDatabase.instance.db;
    final medRow = await database.query('medications', limit: 1);
    return (patientId, medRow.first['id'] as int);
  }

  test('a freshly added medication shows the picked wall-clock time',
      () async {
    final (patientId, _) = await seed(time: '08:00');

    final today = await doses.getDosesForDay(patientId);

    expect(today, hasLength(1));
    expect(today.first.time, '08:00',
        reason: 'the hour the user picked is the hour shown');
  });

  test('restored dose logs do not double today, despite null schedule ids',
      () async {
    // Every dose log in a real backup carries scheduleTimeId null, which the
    // old dedupe key (medication-scheduleTimeId) could never match — so the
    // lazy creator added a second log for every restored dose.
    final (patientId, medId) = await seed(time: '08:00');
    final database = await AppDatabase.instance.db;
    final day = DateTime.now();
    await database.insert('dose_logs', {
      'medication_id': medId,
      'schedule_time_id': null, // exactly how importPatientData writes it
      'scheduled_at': DateTime(day.year, day.month, day.day, 8, 0)
          .toUtc()
          .toIso8601String(),
      'status': 'taken',
      'quantity': 1,
    });

    final today = await doses.getDosesForDay(patientId);

    expect(today, hasLength(1),
        reason: 'the restored log is the dose; no second copy is created');
    expect(today.first.status.name, 'taken',
        reason: 'and it is the restored one, keeping its history');
  });

  test('two screens asking for the day at once create one set of logs',
      () async {
    // Home and Schedule load in the same frame; unserialised, both saw an
    // empty day and both inserted — the "every dose shows twice" reports.
    final (patientId, _) = await seed(time: '08:00');

    final results = await Future.wait([
      doses.getDosesForDay(patientId),
      doses.getDosesForDay(patientId),
      doses.getDosesForDay(patientId),
    ]);

    for (final r in results) {
      expect(r, hasLength(1), reason: 'no duplicate from the race');
    }
  });

  test('a database already holding duplicates heals on the next load',
      () async {
    final (patientId, medId) = await seed(time: '08:00');
    final database = await AppDatabase.instance.db;
    final day = DateTime.now();
    final at = DateTime(day.year, day.month, day.day, 8, 0)
        .toUtc()
        .toIso8601String();
    // Two surplus copies, one carrying history — the healed survivor.
    for (final status in ['taken', 'pending']) {
      await database.insert('dose_logs', {
        'medication_id': medId,
        'schedule_time_id': null,
        'scheduled_at': at,
        'status': status,
        'quantity': 1,
      });
    }

    final today = await doses.getDosesForDay(patientId);

    expect(today, hasLength(1));
    expect(today.first.status.name, 'taken',
        reason: 'the row with history survives the healing');
  });

  test("a signed-out profile does not see another patient's doses", () async {
    final (accountPatient, _) = await seed();
    final guest = await patients.createPatient(fullName: '');

    expect(await doses.getDosesForDay(accountPatient), hasLength(1));
    expect(await doses.getDosesForDay(guest), isEmpty,
        reason: 'dose queries are scoped to the requested patient');
  });
}
