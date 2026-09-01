import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/ui/features/onboarding/view_models/onboarding_view_model.dart';

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

  OnboardingViewModel build({int? accountUserId = 7}) => OnboardingViewModel(
        accountUserId: accountUserId,
        accountEmail: accountUserId == null ? null : 'a@b.com',
      );

  // App Store Guideline 5.1.1(v): the app may not demand personal details
  // before it works, so onboarding creates the profile whatever is filled in.
  test('a blank form still creates a profile rather than blocking', () async {
    final vm = build();
    final id = await vm.start(fullName: '   ', heightCm: '', weightKg: '');

    expect(id, isNotNull);
    final p = await patients.getPatient(id!);
    expect(p!.fullName, isEmpty);
    expect(p.heightCm, isNull);
    expect(p.dob, isNull);
  });

  test('skipping the form entirely creates a usable profile', () async {
    final vm = build(accountUserId: null);
    final id = await vm.start();

    expect(id, isNotNull);
    expect((await patients.getLocalPatient())!.id, id);
  });

  test('creates the profile and attaches it to the account', () async {
    final vm = build();
    vm.setGender('male');
    vm.setDob('1990-05-20');

    final id =
        await vm.start(fullName: ' Quan ', heightCm: '170', weightKg: '65');

    expect(id, isNotNull);
    final p = await patients.getPatient(id!);
    expect(p!.fullName, 'Quan', reason: 'trimmed');
    expect(p.heightCm, 170);
    expect(p.gender, 'male');
    expect(p.accountUserId, 7);
  });

  test('non-numeric measurements are stored as null, not garbage', () async {
    final vm = build();
    final id = await vm.start(fullName: 'Quan', heightCm: 'abc', weightKg: '');

    final p = await patients.getPatient(id!);
    expect(p!.heightCm, isNull);
    expect(p.weightKg, isNull);
  });

  // App Store Guideline 5.1.1(v): onboarding has to work with no account at
  // all, and the profile it leaves behind is the one the app runs on.
  test('without an account the profile is created and owned by nobody',
      () async {
    final vm = build(accountUserId: null);
    final id = await vm.start(fullName: 'Quan', heightCm: '170', weightKg: '');

    expect(id, isNotNull);
    final local = await patients.getLocalPatient();
    expect(local, isNotNull);
    expect(local!.id, id);
    expect(local.accountUserId, isNull);
  });
}
