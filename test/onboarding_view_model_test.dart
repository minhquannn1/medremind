import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/data/services/doctor_sync_service.dart';
import 'package:medremind/ui/features/onboarding/view_models/onboarding_view_model.dart';

/// Stands in for the network so pairing outcomes are chosen, not awaited.
class _FakeDoctorApi implements DoctorSyncApi {
  _FakeDoctorApi({this.pairResult});

  final PairResult? pairResult;
  int syncCount = 0;

  @override
  Future<PairResult> pairWithDoctor(String code) async =>
      pairResult ?? const PairResult.success('BS Nguyen');

  @override
  Future<bool> syncToDoctor(int patientId) async {
    syncCount++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  OnboardingViewModel build({DoctorSyncApi? doctors}) => OnboardingViewModel(
        accountUserId: 7,
        accountEmail: 'a@b.com',
        doctors: doctors ?? _FakeDoctorApi(),
      );

  test('a blank name is rejected before anything is created', () async {
    final vm = build();
    final id = await vm.start(
        fullName: '   ', heightCm: '', weightKg: '', pairCode: '');

    expect(id, isNull);
    expect(vm.nameErrorKey, 'auth.errorMissingFields');
    expect(await patients.getPatientByAccount(7), isNull);
  });

  test('creates the profile and attaches it to the account', () async {
    final vm = build();
    vm.setGender('male');
    vm.setDob('1990-05-20');

    final id = await vm.start(
        fullName: ' Quan ', heightCm: '170', weightKg: '65', pairCode: '');

    expect(id, isNotNull);
    final p = await patients.getPatient(id!);
    expect(p!.fullName, 'Quan', reason: 'trimmed');
    expect(p.heightCm, 170);
    expect(p.gender, 'male');
    expect(p.accountUserId, 7);
  });

  test('non-numeric measurements are stored as null, not garbage', () async {
    final vm = build();
    final id = await vm.start(
        fullName: 'Quan', heightCm: 'abc', weightKg: '', pairCode: '');

    final p = await patients.getPatient(id!);
    expect(p!.heightCm, isNull);
    expect(p.weightKg, isNull);
  });

  test('an invalid code blocks onboarding and creates no profile', () async {
    final api = _FakeDoctorApi(
        pairResult: const PairResult.failure(PairError.invalidCode));
    final vm = build(doctors: api);

    final id = await vm.start(
        fullName: 'Quan', heightCm: '', weightKg: '', pairCode: 'MED-NOPE');

    expect(id, isNull);
    expect(vm.pairErrorKey, 'doctor.invalidCode');
    expect(await patients.getPatientByAccount(7), isNull,
        reason: 'a typo must be fixable before a profile exists');
    expect(api.syncCount, 0);
  });

  test('a network failure reports differently from a wrong code', () async {
    final vm = build(
      doctors: _FakeDoctorApi(
          pairResult: const PairResult.failure(PairError.network)),
    );

    await vm.start(
        fullName: 'Quan', heightCm: '', weightKg: '', pairCode: 'MED-ABC123');

    expect(vm.pairErrorKey, 'doctor.networkError');
  });

  test('a valid code pushes the first snapshot immediately', () async {
    final api = _FakeDoctorApi();
    final vm = build(doctors: api);

    final id = await vm.start(
        fullName: 'Quan', heightCm: '', weightKg: '', pairCode: 'MED-ABC123');

    expect(id, isNotNull);
    expect(api.syncCount, 1,
        reason: 'the doctor should open a real profile, not an empty one');
  });

  test('no code means no pairing attempt at all', () async {
    final api = _FakeDoctorApi();
    final vm = build(doctors: api);

    await vm.start(
        fullName: 'Quan', heightCm: '', weightKg: '', pairCode: '   ');

    expect(api.syncCount, 0);
    expect(await SettingsRepository().get(SettingsKeys.doctorPairCode), isNull);
  });
}
