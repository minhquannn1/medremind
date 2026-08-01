import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/appointments_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/ui/features/schedule/view_models/schedule_view_model.dart';

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

  Future<int> seed({List<String> times = const []}) async {
    final id = await patients.createPatient(fullName: 'P');
    if (times.isNotEmpty) {
      await prescriptions.createPrescription(PrescriptionInput(
        patientId: id,
        medications: [
          MedicationInput(
            name: 'Med',
            times: times.map((t) => MedicationTimeInput(time: t)).toList(),
          ),
        ],
      ));
    }
    return id;
  }

  group('groupedDoses', () {
    test('buckets by part of day', () async {
      // Bucket boundaries follow partOfDay(): <11 morning, <14 noon,
      // <18 evening, otherwise night.
      final id = await seed(times: ['08:00', '12:30', '16:00', '22:00']);
      final vm = ScheduleViewModel(patientId: id);
      await vm.load();

      final groups = vm.groupedDoses;
      expect(groups[PartOfDay.morning]!.single.time, '08:00');
      expect(groups[PartOfDay.noon]!.single.time, '12:30');
      expect(groups[PartOfDay.evening]!.single.time, '16:00');
      expect(groups[PartOfDay.night]!.single.time, '22:00');
    });

    test('keeps morning first even when a later dose is stored first',
        () async {
      final id = await seed(times: ['22:00', '08:00']);
      final vm = ScheduleViewModel(patientId: id);
      await vm.load();

      expect(vm.groupedDoses.keys.toList(),
          [PartOfDay.morning, PartOfDay.night],
          reason: 'evening must never render above morning');
    });

    test('omits empty buckets rather than showing blank headings', () async {
      final id = await seed(times: ['08:00']);
      final vm = ScheduleViewModel(patientId: id);
      await vm.load();

      expect(vm.groupedDoses.keys, [PartOfDay.morning]);
    });

    test('sorts doses within a bucket', () async {
      final id = await seed(times: ['09:30', '07:00', '08:15']);
      final vm = ScheduleViewModel(patientId: id);
      await vm.load();

      expect(
        vm.groupedDoses[PartOfDay.morning]!.map((d) => d.time).toList(),
        ['07:00', '08:15', '09:30'],
      );
    });
  });

  group('isEmpty', () {
    test('is true with neither doses nor appointments', () async {
      final id = await seed();
      final vm = ScheduleViewModel(patientId: id);
      await vm.load();
      expect(vm.isEmpty, isTrue);
    });

    test('is false when only an appointment exists', () async {
      final id = await seed();
      await appointments.createAppointment(
        patientId: id,
        type: 'revisit',
        date: DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      );
      final vm = ScheduleViewModel(patientId: id);
      await vm.load();

      expect(vm.isEmpty, isFalse,
          reason: 'an appointment must not render the "no schedule" state');
      expect(vm.groupedDoses, isEmpty);
    });
  });

  group('appointments', () {
    test('shows upcoming only and deleting refreshes the list', () async {
      final id = await seed();
      await appointments.createAppointment(
        patientId: id,
        type: 'revisit',
        date: DateTime.now()
            .subtract(const Duration(days: 3))
            .toUtc()
            .toIso8601String(),
      );
      await appointments.createAppointment(
        patientId: id,
        type: 'refill',
        date:
            DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(),
      );

      final vm = ScheduleViewModel(patientId: id);
      await vm.load();
      expect(vm.upcoming.length, 1);
      expect(vm.upcoming.single.type, 'refill');

      await vm.deleteAppointment(vm.upcoming.single.id);
      expect(vm.upcoming, isEmpty);
    });
  });

  test('a signed-out view model stops loading', () async {
    final vm = ScheduleViewModel(patientId: null);
    await vm.load();
    expect(vm.loading, isFalse);
    expect(vm.isEmpty, isTrue);
  });
}
