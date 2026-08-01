import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/ui/features/profile/view_models/profile_view_model.dart';

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

  Future<ProfileViewModel> loaded({
    String name = 'Nguyen Van An',
    double? height,
    double? weight,
    String? dob,
  }) async {
    final id = await patients.createPatient(
      fullName: name,
      heightCm: height,
      weightKg: weight,
      dob: dob,
    );
    final vm = ProfileViewModel(patientId: id);
    await vm.load();
    return vm;
  }

  group('initials', () {
    test('takes the last two words, matching Vietnamese name order', () async {
      final vm = await loaded(name: 'Nguyen Van An');
      expect(vm.initials, 'VA',
          reason: 'the given name comes last in Vietnamese');
    });

    test('handles a single-word name', () async {
      final vm = await loaded(name: 'Quan');
      expect(vm.initials, 'Q');
    });

    test('collapses extra whitespace', () async {
      final vm = await loaded(name: '  Tran   Thi  Mai  ');
      expect(vm.initials, 'TM');
    });

    test('falls back to a placeholder rather than crashing', () {
      final vm = ProfileViewModel(patientId: null);
      expect(vm.initials, '?');
    });
  });

  group('bmi', () {
    test('computes from height and weight', () async {
      final vm = await loaded(height: 170, weight: 65);
      expect(vm.bmi, closeTo(22.49, 0.01));
    });

    test('is null when a measurement is missing', () async {
      expect((await loaded(height: 170)).bmi, isNull);
      expect((await loaded(weight: 65)).bmi, isNull);
      expect((await loaded()).bmi, isNull);
    });

    test('is null for a zero height instead of infinity', () async {
      final vm = await loaded(height: 0, weight: 65);
      expect(vm.bmi, isNull,
          reason: 'dividing by zero would render "Infinity" to the user');
    });
  });

  group('editing', () {
    test('drafts start from the stored values', () async {
      final vm = await loaded(height: 170, weight: 65, dob: '1990-05-20');
      vm.startEditing();

      expect(vm.editing, isTrue);
      expect(vm.heightDraft, '170');
      expect(vm.weightDraft, '65');
      expect(vm.dobDraft, '1990-05-20');
    });

    test('cancelling discards the edits', () async {
      final vm = await loaded(height: 170, weight: 65);
      vm.startEditing();
      vm.heightDraft = '999';
      vm.setGender('other');

      vm.cancelEditing();

      expect(vm.editing, isFalse);
      expect(vm.heightDraft, '170', reason: 'draft reverted');
      expect(vm.patient!.heightCm, 170, reason: 'record never touched');
    });

    test('saving persists and leaves edit mode', () async {
      final vm = await loaded(height: 170, weight: 65);
      vm.startEditing();
      vm.heightDraft = '175';
      vm.weightDraft = '70';
      vm.setGender('male');

      await vm.saveMetrics();

      expect(vm.editing, isFalse);
      expect(vm.patient!.heightCm, 175);
      expect(vm.patient!.weightKg, 70);
      expect(vm.patient!.gender, 'male');
    });

    test('a blank measurement clears it rather than saving garbage', () async {
      final vm = await loaded(height: 170, weight: 65);
      vm.startEditing();
      vm.heightDraft = '';

      await vm.saveMetrics();

      expect(vm.patient!.heightCm, isNull);
      expect(vm.bmi, isNull);
    });

    test('non-numeric input does not corrupt the record', () async {
      final vm = await loaded(height: 170, weight: 65);
      vm.startEditing();
      vm.weightDraft = 'abc';

      await vm.saveMetrics();

      expect(vm.patient!.weightKg, isNull);
    });
  });

  group('load', () {
    test('a signed-out view model stops loading', () async {
      final vm = ProfileViewModel(patientId: null);
      await vm.load();
      expect(vm.loading, isFalse);
      expect(vm.patient, isNull);
    });

    test('conditions and allergies are read-only to the view', () async {
      final vm = await loaded();
      expect(() => vm.conditions.clear(), throwsUnsupportedError);
      expect(() => vm.allergies.clear(), throwsUnsupportedError);
    });
  });
}
