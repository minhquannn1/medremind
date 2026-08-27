import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/data/services/database.dart';
import 'package:medremind/domain/models/models.dart';

/// Patient profile, conditions and allergies.
/// Ported from `src/db/repositories/patients.ts`.
class PatientsRepository {
  const PatientsRepository();

  Future<int> createPatient({
    required String fullName,
    String? dob,
    String? gender,
    double? heightCm,
    double? weightKg,
    int? accountUserId,
    String? accountEmail,
  }) async {
    final database = await AppDatabase.instance.db;
    return database.insert('patients', {
      'full_name': fullName,
      'dob': dob,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'account_user_id': accountUserId,
      'account_email': accountEmail,
      'created_at': nowIso(),
    });
  }

  Future<Patient?> getPatient(int id) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  /// The local patient profile owned by a given server account, if any.
  Future<Patient?> getPatientByAccount(int accountUserId) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'patients',
      where: 'account_user_id = ?',
      whereArgs: [accountUserId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  /// The on-device profile that belongs to no account. This is what a user
  /// gets when they use the app without signing in, which the App Store
  /// requires us to allow (Guideline 5.1.1(v)): reminders are local, so an
  /// account is only needed for cloud backup.
  Future<Patient?> getLocalPatient() async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'patients',
      where: 'account_user_id IS NULL',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  /// A patient profile that belongs to no account. Used when an account signs
  /// in or signs up on a device already used without one, so existing
  /// on-device data carries over instead of being stranded.
  Future<Patient?> claimOrphanPatient(
    int accountUserId,
    String accountEmail,
  ) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'patients',
      where: 'account_user_id IS NULL',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final orphan = Patient.fromMap(rows.first);
    await database.update(
      'patients',
      {'account_user_id': accountUserId, 'account_email': accountEmail},
      where: 'id = ?',
      whereArgs: [orphan.id],
    );
    return orphan.copyWith(
      accountUserId: accountUserId,
      accountEmail: accountEmail,
    );
  }

  /// Partial update. Only the fields present in [values] are written, matching
  /// the RN `updatePatient(id, Partial<...>)` contract — passing an explicit
  /// null clears the column.
  Future<void> updatePatient(int id, Map<String, Object?> values) async {
    if (values.isEmpty) return;
    final database = await AppDatabase.instance.db;
    await database.update(
      'patients',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---- Medical conditions ---------------------------------------------------

  Future<List<MedicalCondition>> listConditions(int patientId) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'medical_conditions',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
    return rows.map(MedicalCondition.fromMap).toList();
  }

  Future<void> addCondition(int patientId, String name, {String? note}) async {
    final database = await AppDatabase.instance.db;
    await database.insert('medical_conditions', {
      'patient_id': patientId,
      'name': name,
      'note': note,
      'created_at': nowIso(),
    });
  }

  Future<void> removeCondition(int id) async {
    final database = await AppDatabase.instance.db;
    await database.delete('medical_conditions', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Allergies ------------------------------------------------------------

  Future<List<Allergy>> listAllergies(int patientId) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'allergies',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
    return rows.map(Allergy.fromMap).toList();
  }

  Future<void> addAllergy(
    int patientId,
    String substance, {
    String? severity,
    String? reaction,
  }) async {
    final database = await AppDatabase.instance.db;
    await database.insert('allergies', {
      'patient_id': patientId,
      'substance': substance,
      'severity': severity,
      'reaction': reaction,
      'created_at': nowIso(),
    });
  }

  Future<void> removeAllergy(int id) async {
    final database = await AppDatabase.instance.db;
    await database.delete('allergies', where: 'id = ?', whereArgs: [id]);
  }
}
