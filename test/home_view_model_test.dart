import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/ui/features/home/view_models/home_view_model.dart';

/// The point of extracting a ViewModel: this logic used to live inside the
/// widget, so checking it meant building a widget tree. Now it is plain Dart.
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

  Future<int> seedPatient({List<String> times = const ['08:00']}) async {
    final id = await patients.createPatient(fullName: 'Nguyen Van A');
    if (times.isNotEmpty) {
      await prescriptions.createPrescription(PrescriptionInput(
        patientId: id,
        medications: [
          MedicationInput(
            name: 'Amlodipin 5mg',
            dosage: '1 vien',
            quantityTotal: 30,
            times: times.map((t) => MedicationTimeInput(time: t)).toList(),
          ),
        ],
      ));
    }
    return id;
  }

  group('greeting', () {
    HomeViewModel atHour(int hour) => HomeViewModel(
          patientId: null,
          now: () => DateTime(2026, 8, 1, hour),
        );

    test('buckets the hour into morning, afternoon and evening', () {
      expect(atHour(6).greeting, GreetingSlot.morning);
      expect(atHour(10).greeting, GreetingSlot.morning);
      expect(atHour(11).greeting, GreetingSlot.afternoon);
      expect(atHour(17).greeting, GreetingSlot.afternoon);
      expect(atHour(18).greeting, GreetingSlot.evening);
      expect(atHour(23).greeting, GreetingSlot.evening);
    });

    test('midnight is morning, not evening', () {
      expect(atHour(0).greeting, GreetingSlot.morning);
    });
  });

  group('adherence display', () {
    test('shows a dash rather than 0% when nothing was due', () async {
      final id = await patients.createPatient(fullName: 'Empty');
      final vm = HomeViewModel(patientId: id);
      await vm.load();

      expect(vm.adherence.total, 0);
      expect(vm.adherenceLabel, '—',
          reason: 'a patient with no doses has not failed to take them');
      expect(vm.adherenceCount, '0/0');
    });

    test('reports a percentage once a dose is taken', () async {
      final id = await seedPatient();
      final vm = HomeViewModel(patientId: id);
      await vm.load();

      await vm.mark(vm.today.single, DoseStatus.taken);

      expect(vm.adherence.taken, 1);
      expect(vm.adherenceLabel, endsWith('%'));
    });
  });

  group('allDone', () {
    test('is false for an empty day', () async {
      final id = await patients.createPatient(fullName: 'Empty');
      final vm = HomeViewModel(patientId: id);
      await vm.load();

      expect(vm.today, isEmpty);
      expect(vm.allDone, isFalse,
          reason: 'no doses is not the same as finishing them');
    });

    test('is false while a dose is still pending', () async {
      final id = await seedPatient(times: ['08:00', '20:00']);
      final vm = HomeViewModel(patientId: id);
      await vm.load();

      await vm.mark(vm.today.first, DoseStatus.taken);
      expect(vm.pending.length, 1);
      expect(vm.allDone, isFalse);
    });

    test('is true once every dose is resolved, including skipped', () async {
      final id = await seedPatient(times: ['08:00', '20:00']);
      final vm = HomeViewModel(patientId: id);
      await vm.load();

      await vm.mark(vm.today.first, DoseStatus.taken);
      await vm.mark(vm.pending.single, DoseStatus.skipped);

      expect(vm.pending, isEmpty);
      expect(vm.allDone, isTrue);
    });
  });

  group('load', () {
    test('a signed-out view model stops loading instead of hanging', () async {
      final vm = HomeViewModel(patientId: null);
      await vm.load();
      expect(vm.loading, isFalse);
      expect(vm.today, isEmpty);
    });

    test('notifies listeners so the view repaints', () async {
      final id = await seedPatient();
      final vm = HomeViewModel(patientId: id);

      var notifications = 0;
      vm.addListener(() => notifications++);

      await vm.load();
      expect(notifications, greaterThan(0));
    });

    test('exposes an unmodifiable dose list', () async {
      final id = await seedPatient();
      final vm = HomeViewModel(patientId: id);
      await vm.load();

      expect(() => vm.today.clear(), throwsUnsupportedError,
          reason: 'the view must not mutate the view model state');
    });
  });

  group('mark', () {
    test('taking a dose deducts stock', () async {
      final id = await seedPatient();
      final vm = HomeViewModel(patientId: id);
      await vm.load();
      final medicationId = vm.today.single.medicationId;

      await vm.mark(vm.today.single, DoseStatus.taken);

      final med = await prescriptions.getMedication(medicationId);
      expect(med!.quantityRemaining, 29);
    });

    test('reloads so the screen reflects the new status', () async {
      final id = await seedPatient();
      final vm = HomeViewModel(patientId: id);
      await vm.load();

      await vm.mark(vm.today.single, DoseStatus.taken);
      expect(vm.today.single.status, DoseStatus.taken);
    });
  });
}
