import '../../lib_date.dart';
import '../database.dart';
import '../models.dart';

/// Revisit / refill appointments.
/// Ported from `src/db/repositories/appointments.ts`.
class AppointmentsRepository {
  const AppointmentsRepository();

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  /// Appointments falling on one calendar day, for the schedule screen.
  Future<List<Appointment>> listAppointmentsForDay(
    int patientId,
    DateTime day,
  ) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'appointments',
      where: 'patient_id = ? AND date >= ? AND date <= ?',
      whereArgs: [patientId, _iso(_startOfDay(day)), _iso(_endOfDay(day))],
      orderBy: 'date ASC',
    );
    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> listUpcomingAppointments(int patientId) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'appointments',
      where: 'patient_id = ? AND date >= ?',
      whereArgs: [patientId, _iso(_startOfDay(DateTime.now()))],
      orderBy: 'date ASC',
    );
    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> listAllAppointments(int patientId) async {
    final database = await AppDatabase.instance.db;
    final rows = await database.query(
      'appointments',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'date ASC',
    );
    return rows.map(Appointment.fromMap).toList();
  }

  Future<int> createAppointment({
    required int patientId,
    required String type, // revisit | refill
    required String date, // ISO datetime
    String? note,
    String? notificationId,
  }) async {
    final database = await AppDatabase.instance.db;
    return database.insert('appointments', {
      'patient_id': patientId,
      'type': type,
      'date': date,
      'note': note,
      'notification_id': notificationId,
      'created_at': nowIso(),
    });
  }

  Future<void> deleteAppointment(int id) async {
    final database = await AppDatabase.instance.db;
    await database.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }
}
