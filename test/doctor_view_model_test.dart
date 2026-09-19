import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medremind/data/services/database.dart';
import 'package:medremind/data/services/doctor_sync_service.dart';
import 'package:medremind/ui/features/doctor/view_models/doctor_view_model.dart';

/// The doctor connection, restored after its removal for App Review. Pairing
/// outcomes are chosen by a fake so no test waits on a network.
class _FakeDoctorApi implements DoctorSyncApi {
  _FakeDoctorApi({this.pairResult, this.link});

  PairResult? pairResult;
  DoctorLink? link;
  int syncCount = 0;
  bool unlinked = false;

  @override
  Future<PairResult> pairWithDoctor(String code) async =>
      pairResult ?? const PairResult.success('BS Trần Thu Hà');

  @override
  Future<bool> syncToDoctor(int patientId) async {
    syncCount++;
    return true;
  }

  @override
  Future<DoctorLink?> getDoctorLink() async => link;

  @override
  Future<void> unlinkDoctor() async {
    unlinked = true;
    link = null;
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

  test('a valid code pairs and pushes the first snapshot immediately',
      () async {
    final api = _FakeDoctorApi(
        link: const DoctorLink(pairCode: 'MED-ABC123', doctorName: 'BS Hà'));
    final vm = DoctorViewModel(patientId: 1, api: api);

    final ok = await vm.connect('MED-ABC123');

    expect(ok, isTrue);
    expect(api.syncCount, 1,
        reason: 'the doctor opens a real profile, not an empty one');
    expect(vm.isLinked, isTrue);
    expect(vm.errorKey, isNull);
  });

  test('an invalid code reports itself and pushes nothing', () async {
    final api = _FakeDoctorApi(
        pairResult: const PairResult.failure(PairError.invalidCode));
    final vm = DoctorViewModel(patientId: 1, api: api);

    expect(await vm.connect('MED-NOPE99'), isFalse);
    expect(vm.errorKey, 'doctor.invalidCode');
    expect(api.syncCount, 0);
    expect(vm.isLinked, isFalse);
  });

  test('a network failure reads differently from a wrong code', () async {
    final api = _FakeDoctorApi(
        pairResult: const PairResult.failure(PairError.network));
    final vm = DoctorViewModel(patientId: 1, api: api);

    await vm.connect('MED-ABC123');
    expect(vm.errorKey, 'doctor.networkError');
  });

  test('disconnect unlinks and clears the shown doctor', () async {
    final api = _FakeDoctorApi(
        link: const DoctorLink(pairCode: 'MED-ABC123', doctorName: 'BS Hà'));
    final vm = DoctorViewModel(patientId: 1, api: api);
    await vm.load();
    expect(vm.isLinked, isTrue);

    await vm.disconnect();

    expect(api.unlinked, isTrue);
    expect(vm.isLinked, isFalse);
  });

  test('an empty code is rejected before any network call', () async {
    final api = _FakeDoctorApi();
    final vm = DoctorViewModel(patientId: 1, api: api);
    expect(await vm.connect('   '), isFalse);
    expect(api.syncCount, 0);
  });
}
