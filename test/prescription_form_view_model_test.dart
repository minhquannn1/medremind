import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/domain/models/medication_draft.dart';
import 'package:medremind/ui/features/prescriptions/view_models/prescription_form_view_model.dart';

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

  Future<PrescriptionFormViewModel> form({
    List<MedicationDraft>? drafts,
  }) async {
    final id = await patients.createPatient(fullName: 'P');
    return PrescriptionFormViewModel(patientId: id, initialDrafts: drafts);
  }

  MedicationDraft draft({
    String name = 'Med',
    List<String>? times,
    String dosage = '',
  }) {
    final d = MedicationDraft.empty()
      ..name = name
      ..dosage = dosage;
    if (times != null) d.times = times;
    return d;
  }

  group('validation', () {
    test('an empty form reports a missing name on the only row', () async {
      final vm = await form();
      final problem = vm.validate();

      expect(problem, isNotNull);
      expect(problem!.messageKey, 'prescriptions.errorMissingName');
      expect(vm.isIncomplete(vm.drafts.single), isTrue);
    });

    test('names the medication position so the user finds the row', () async {
      // A dosage without a name is a half-filled row, not an unused slot.
      final vm = await form(
          drafts: [draft(name: 'A'), draft(name: '', dosage: '1 vien')]);
      final problem = vm.validate();

      expect(problem!.params['index'], 2);
    });

    test('a medication with no intake time is rejected', () async {
      final vm = await form(drafts: [draft(name: 'Amlodipin', times: [])]);
      final problem = vm.validate();

      expect(problem!.messageKey, 'prescriptions.errorMissingTime');
      expect(problem.params['name'], 'Amlodipin',
          reason: 'the message should say which medicine');
    });

    test('an untouched extra row is an unused slot, not an error', () async {
      final vm = await form(drafts: [draft(name: 'A'), MedicationDraft.empty()]);
      expect(vm.validate(), isNull);
    });

    test('marks every incomplete row, not only the first', () async {
      final vm = await form(drafts: [
        draft(name: '', dosage: '1 vien'),
        draft(name: 'B', times: []),
        draft(name: 'C'),
      ]);
      vm.validate();

      expect(vm.isIncomplete(vm.drafts[0]), isTrue);
      expect(vm.isIncomplete(vm.drafts[1]), isTrue);
      expect(vm.isIncomplete(vm.drafts[2]), isFalse);
    });

    test('a complete form passes', () async {
      final vm = await form(drafts: [draft(name: 'Amlodipin 5mg')]);
      expect(vm.validate(), isNull);
    });
  });

  group('save', () {
    test('refuses to write an invalid form', () async {
      final vm = await form();
      final id = await vm.save(doctorName: '', clinic: '', notes: '');

      expect(id, isNull);
      expect(vm.error, isNotNull);
      expect(await prescriptions.listPrescriptions(vm.patientId!), isEmpty);
    });

    test('persists the prescription and its medications', () async {
      final vm = await form(drafts: [
        draft(name: 'Amlodipin 5mg', times: ['08:00', '20:00']),
      ]);

      final id = await vm.save(
          doctorName: ' BS Nguyen ', clinic: ' Cho Ray ', notes: '  ');

      expect(id, isNotNull);
      final saved = (await prescriptions.listPrescriptions(vm.patientId!)).single;
      expect(saved.doctorName, 'BS Nguyen', reason: 'trimmed');
      expect(saved.notes, isNull, reason: 'blank notes stored as null');

      final meds = await prescriptions.listMedications(id!);
      expect(meds.single.name, 'Amlodipin 5mg');
      final times = await prescriptions.listScheduleTimes(meds.single.id);
      expect(times.length, 2);
    });

    test('skips unused rows instead of saving empty medications', () async {
      final vm = await form(drafts: [draft(name: 'A'), MedicationDraft.empty()]);
      final id = await vm.save(doctorName: '', clinic: '', notes: '');

      expect((await prescriptions.listMedications(id!)).length, 1);
    });
  });

  group('draft list', () {
    test('starts with one row so the form is never empty', () async {
      final vm = await form();
      expect(vm.drafts.length, 1);
    });

    test('adding and removing rows notifies the view', () async {
      final vm = await form();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.addDraft();
      expect(vm.drafts.length, 2);
      vm.removeDraft(vm.drafts.last);
      expect(vm.drafts.length, 1);
      expect(notifications, 2);
    });
  });
}
