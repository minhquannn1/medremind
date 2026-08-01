import 'package:flutter/foundation.dart';

import 'package:medremind/data/services/doctor_sync_service.dart';

/// Pairing with a doctor and pushing snapshots.
class DoctorViewModel extends ChangeNotifier {
  DoctorViewModel({
    required this.patientId,
    this.api = const DoctorSyncApi(),
  });

  final int? patientId;
  final DoctorSyncApi api;

  DoctorLink? _link;
  DoctorLink? get link => _link;

  bool _busy = false;
  bool get busy => _busy;

  /// i18n key for the last failure, or null.
  String? _errorKey;
  String? get errorKey => _errorKey;

  bool _disposed = false;

  bool get isLinked => _link != null;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _link = await api.getDoctorLink();
    _notify();
  }

  /// Returns true when the code was accepted.
  Future<bool> connect(String code) async {
    if (code.trim().isEmpty) return false;

    _busy = true;
    _errorKey = null;
    _notify();

    final res = await api.pairWithDoctor(code);
    if (!res.ok) {
      _busy = false;
      _errorKey = res.error == PairError.invalidCode
          ? 'doctor.invalidCode'
          : 'doctor.networkError';
      _notify();
      return false;
    }

    // Push straight away so the doctor opens a real profile, not an empty one.
    final id = patientId;
    if (id != null) await api.syncToDoctor(id);

    await load();
    _busy = false;
    _notify();
    return true;
  }

  /// Returns true when the snapshot reached the server.
  Future<bool> syncNow() async {
    final id = patientId;
    if (id == null) return false;

    _busy = true;
    _notify();
    final ok = await api.syncToDoctor(id);
    _busy = false;
    _notify();
    return ok;
  }

  Future<void> disconnect() async {
    await api.unlinkDoctor();
    _link = null;
    _notify();
  }
}
