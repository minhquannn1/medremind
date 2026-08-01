import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/ui/features/dose_confirm/view_models/dose_confirm_view_model.dart';
import 'package:medremind/ui/features/history/view_models/history_view_model.dart';
import 'package:medremind/ui/features/prescriptions/view_models/prescriptions_view_model.dart';

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

  group('PrescriptionsViewModel', () {
    test('counts the medications on each prescription', () async {
      final id = await patients.createPatient(fullName: 'P');
      final presId = await prescriptions.createPrescription(PrescriptionInput(
        patientId: id,
        doctorName: 'BS Nguyen',
        clinic: 'Cho Ray',
        medications: const [
          MedicationInput(name: 'A'),
          MedicationInput(name: 'B'),
        ],
      ));

      final vm = PrescriptionsViewModel(patientId: id);
      await vm.load();

      expect(vm.items.single.id, presId);
      expect(vm.medicationCount(presId), 2);
    });

    test('joins doctor and clinic, and returns null when both are blank',
        () async {
      final id = await patients.createPatient(fullName: 'P');
      await prescriptions.createPrescription(
          PrescriptionInput(patientId: id, doctorName: 'BS Nguyen'));
      await prescriptions.createPrescription(
          PrescriptionInput(patientId: id, doctorName: '  ', clinic: ''));

      final vm = PrescriptionsViewModel(patientId: id);
      await vm.load();

      final titles = vm.items.map(vm.titleFor).toList();
      expect(titles, contains('BS Nguyen'));
      expect(titles, contains(null),
          reason: 'the view falls back to a generic label rather than " · "');
    });

    test('an unknown prescription counts zero rather than throwing', () {
      final vm = PrescriptionsViewModel(patientId: null);
      expect(vm.medicationCount(999), 0);
    });
  });

  group('HistoryViewModel', () {
    test('ratio is null for a day with nothing due', () {
      final vm = HistoryViewModel(patientId: null);
      const day = HistoryDay(date: '2026-08-01', doses: [], taken: 0, total: 0);
      expect(vm.ratioFor(day), isNull,
          reason: 'nothing due is neutral, not a failure');
    });

    test('ratio reflects taken over total', () {
      final vm = HistoryViewModel(patientId: null);
      const day = HistoryDay(date: '2026-08-01', doses: [], taken: 3, total: 4);
      expect(vm.ratioFor(day), 0.75);
    });

    test('a signed-out view model stops loading', () async {
      final vm = HistoryViewModel(patientId: null);
      await vm.load();
      expect(vm.loading, isFalse);
      expect(vm.history, isEmpty);
    });
  });

  group('DoseConfirmViewModel', () {
    Future<int> seedDose({String time = '08:00'}) async {
      final id = await patients.createPatient(fullName: 'P');
      await prescriptions.createPrescription(PrescriptionInput(
        patientId: id,
        medications: [
          MedicationInput(
            name: 'Med',
            quantityTotal: 10,
            times: [MedicationTimeInput(time: time)],
          ),
        ],
      ));
      return id;
    }

    test('finds the dose the reminder points at', () async {
      final id = await seedDose();
      final today = await const DosesRepository().getDosesForDay(id);
      final medicationId = today.single.medicationId;

      final vm = DoseConfirmViewModel(
        patientId: id,
        medicationId: medicationId,
        time: '08:00',
      );
      await vm.load();

      expect(vm.dose, isNotNull);
      expect(vm.isStale, isFalse);
      expect(vm.alreadyResolved, isFalse);
    });

    test('reports a reminder that outlived its dose as stale', () async {
      final id = await seedDose();
      final vm = DoseConfirmViewModel(
        patientId: id,
        medicationId: 999999,
        time: '08:00',
      );
      await vm.load();

      expect(vm.dose, isNull);
      expect(vm.isStale, isTrue,
          reason: 'a deleted prescription must show an empty state, not fail');
    });

    test('a matching medication at a different time is not the dose',
        () async {
      final id = await seedDose(time: '08:00');
      final today = await const DosesRepository().getDosesForDay(id);

      final vm = DoseConfirmViewModel(
        patientId: id,
        medicationId: today.single.medicationId,
        time: '20:00',
      );
      await vm.load();
      expect(vm.isStale, isTrue);
    });

    test('marking records the dose and deducts stock', () async {
      final id = await seedDose();
      final today = await const DosesRepository().getDosesForDay(id);
      final medicationId = today.single.medicationId;

      final vm = DoseConfirmViewModel(
        patientId: id,
        medicationId: medicationId,
        time: '08:00',
      );
      await vm.load();

      expect(await vm.mark(DoseStatus.taken), isTrue);
      expect(vm.saving, isFalse);

      final med = await prescriptions.getMedication(medicationId);
      expect(med!.quantityRemaining, 9);
    });

    test('marking a stale reminder is a no-op, not a crash', () async {
      final id = await seedDose();
      final vm = DoseConfirmViewModel(
        patientId: id,
        medicationId: 999999,
        time: '08:00',
      );
      await vm.load();

      expect(await vm.mark(DoseStatus.taken), isFalse,
          reason: 'the view should stay put rather than pop on nothing');
    });

    test('an already-confirmed dose is reported as resolved', () async {
      final id = await seedDose();
      final today = await const DosesRepository().getDosesForDay(id);
      await const DosesRepository().markDose(today.single.id, DoseStatus.taken);

      final vm = DoseConfirmViewModel(
        patientId: id,
        medicationId: today.single.medicationId,
        time: '08:00',
      );
      await vm.load();

      expect(vm.alreadyResolved, isTrue,
          reason: 'tapping the reminder twice must not deduct stock twice');
    });
  });
}
