import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/ui/features/prescriptions/view_models/medication_detail_view_model.dart';
import 'package:medremind/ui/features/prescriptions/view_models/prescription_detail_view_model.dart';

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

  Future<int> seed({
    String? doctorName,
    String? clinic,
    double? total,
    double? remaining,
    List<String> times = const ['20:00', '08:00'],
  }) async {
    final patientId = await patients.createPatient(fullName: 'P');
    final presId = await prescriptions.createPrescription(PrescriptionInput(
      patientId: patientId,
      doctorName: doctorName,
      clinic: clinic,
      medications: [
        MedicationInput(
          name: 'Amlodipin 5mg',
          quantityTotal: total,
          times: times.map((t) => MedicationTimeInput(time: t)).toList(),
        ),
      ],
    ));
    if (remaining != null) {
      final med = (await prescriptions.listMedications(presId)).single;
      await prescriptions.adjustMedicationStock(
          med.id, remaining - (total ?? 0));
    }
    return presId;
  }

  group('PrescriptionDetailViewModel', () {
    test('sorts each medication\'s intake times', () async {
      final id = await seed();
      final vm = PrescriptionDetailViewModel(prescriptionId: id);
      await vm.load();

      final med = vm.medications.single;
      expect(vm.timesFor(med.id), ['08:00', '20:00'],
          reason: 'stored order must not leak into the display');
    });

    test('title joins doctor and clinic, null when both are blank', () async {
      final withBoth = PrescriptionDetailViewModel(
          prescriptionId: await seed(doctorName: 'BS Nguyen', clinic: 'Cho Ray'));
      await withBoth.load();
      expect(withBoth.title, 'BS Nguyen · Cho Ray');

      final withNeither =
          PrescriptionDetailViewModel(prescriptionId: await seed(clinic: '  '));
      await withNeither.load();
      expect(withNeither.title, isNull,
          reason: 'the view falls back to a label instead of showing " · "');
    });

    test('toggles between active and completed', () async {
      final vm = PrescriptionDetailViewModel(prescriptionId: await seed());
      await vm.load();
      expect(vm.isCompleted, isFalse);

      await vm.toggleStatus();
      expect(vm.isCompleted, isTrue);

      await vm.toggleStatus();
      expect(vm.isCompleted, isFalse);
    });

    test('deleting removes the prescription and its medications', () async {
      final id = await seed();
      final vm = PrescriptionDetailViewModel(prescriptionId: id);
      await vm.load();

      await vm.delete();

      expect(await prescriptions.getPrescription(id), isNull);
      expect(await prescriptions.listMedications(id), isEmpty);
    });

    test('unknown times return an empty list, not null', () async {
      final vm = PrescriptionDetailViewModel(prescriptionId: await seed());
      await vm.load();
      expect(vm.timesFor(999999), isEmpty);
    });
  });

  group('MedicationDetailViewModel', () {
    Future<MedicationDetailViewModel> forMed(int presId) async {
      final med = (await prescriptions.listMedications(presId)).single;
      final vm =
          MedicationDetailViewModel(medicationId: med.id, language: 'vi');
      await vm.load();
      return vm;
    }

    test('flags low stock at a fifth or less of the original', () async {
      final vm = await forMed(await seed(total: 30, remaining: 6));
      expect(vm.isLowStock, isTrue);
    });

    test('does not flag comfortable stock', () async {
      final vm = await forMed(await seed(total: 30, remaining: 20));
      expect(vm.isLowStock, isFalse);
    });

    test('untracked stock is never low', () async {
      final vm = await forMed(await seed());
      expect(vm.medication!.quantityRemaining, isNull);
      expect(vm.isLowStock, isFalse,
          reason: 'no tracked amount must not read as "running out"');
    });

    test('sorts intake times', () async {
      final vm = await forMed(await seed());
      expect(vm.times.map((t) => t.time).toList(), ['08:00', '20:00']);
    });

    test('changing a time persists and re-sorts', () async {
      final vm = await forMed(await seed());
      await vm.changeTime(vm.times.first, '22:00');
      expect(vm.times.map((t) => t.time).toList(), ['20:00', '22:00']);
    });

    test('reports no explanation until one is stored', () async {
      final vm = await forMed(await seed());
      expect(vm.hasExplanation, isFalse);
    });
  });
}
