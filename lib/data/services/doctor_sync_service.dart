import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:medremind/data/repositories/appointments_repository.dart';
import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/data/repositories/patients_repository.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/repositories/settings_repository.dart';
import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/data/services/api_config.dart';

/// Doctor sync: links a patient to a doctor via a pairing code and pushes an
/// adherence snapshot so the doctor's web dashboard can monitor them.
/// Ported from `src/features/sync/doctorSync.ts`.

class DoctorLink {
  final String pairCode;
  final String doctorName;

  const DoctorLink({required this.pairCode, required this.doctorName});
}

enum PairError { invalidCode, network }

class PairResult {
  final bool ok;
  final String? doctorName;
  final PairError? error;

  const PairResult.success(this.doctorName)
      : ok = true,
        error = null;

  const PairResult.failure(this.error)
      : ok = false,
        doctorName = null;
}

class DoctorSyncApi {
  const DoctorSyncApi({
    this.client,
    this.settings = const SettingsRepository(),
    this.patients = const PatientsRepository(),
    this.prescriptions = const PrescriptionsRepository(),
    this.doses = const DosesRepository(),
    this.appointments = const AppointmentsRepository(),
  });

  final http.Client? client;
  final SettingsRepository settings;
  final PatientsRepository patients;
  final PrescriptionsRepository prescriptions;
  final DosesRepository doses;
  final AppointmentsRepository appointments;

  http.Client get _client => client ?? http.Client();

  Future<DoctorLink?> getDoctorLink() async {
    final pairCode = await settings.get(SettingsKeys.doctorPairCode);
    if (pairCode == null || pairCode.isEmpty) return null;
    return DoctorLink(
      pairCode: pairCode,
      doctorName: await settings.get(SettingsKeys.doctorName) ?? '',
    );
  }

  /// Validates a pairing code with the backend and stores the link locally.
  Future<PairResult> pairWithDoctor(String code) async {
    final clean = code.trim().toUpperCase();
    try {
      final res = await _client.get(
        Uri.parse('$apiBase/pair/${Uri.encodeComponent(clean)}'),
        headers: const {'bypass-tunnel-reminder': 'true'},
      ).timeout(requestTimeout);

      if (res.statusCode == 404) {
        return const PairResult.failure(PairError.invalidCode);
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return const PairResult.failure(PairError.network);
      }

      final data = jsonDecode(res.body) as Map<String, Object?>;
      if (data['ok'] != true) {
        return const PairResult.failure(PairError.invalidCode);
      }

      final doctorName = (data['doctorName'] as String?) ?? '';
      await settings.set(SettingsKeys.doctorPairCode, clean);
      await settings.set(SettingsKeys.doctorName, doctorName);
      return PairResult.success(doctorName);
    } catch (_) {
      return const PairResult.failure(PairError.network);
    }
  }

  Future<void> unlinkDoctor() async {
    await settings.set(SettingsKeys.doctorPairCode, '');
    await settings.set(SettingsKeys.doctorName, '');
  }

  /// Builds the payload the doctor dashboard renders. Field names match the
  /// server's `sanitizeSnapshot`, which drops anything it does not recognise.
  Future<Map<String, Object?>> buildSnapshot(int patientId) async {
    final patient = await patients.getPatient(patientId);
    final conditions = await patients.listConditions(patientId);
    final allergies = await patients.listAllergies(patientId);
    final adherence = await doses.getAdherence(patientId, days: 7);
    final adherence30 = await doses.getAdherence(patientId, days: 30);
    final meds = await prescriptions.listActiveMedicationsWithSchedule(patientId);
    final history = await doses.getDoseHistory(patientId, days: 30);
    final prescriptionList = await prescriptions.listPrescriptions(patientId);
    final upcoming = await appointments.listUpcomingAppointments(patientId);

    final prescriptionPayload = <Map<String, Object?>>[];
    for (final p in prescriptionList) {
      final count = (await prescriptions.listMedications(p.id)).length;
      prescriptionPayload.add({
        'id': p.id,
        'doctorName': p.doctorName,
        'clinic': p.clinic,
        'issuedDate': p.issuedDate,
        'status': p.status,
        'notes': p.notes,
        'createdAt': p.createdAt,
        'medicationCount': count,
      });
    }

    return {
      'patient': {
        'name': patient?.fullName ?? '',
        'age': ageFromDob(patient?.dob),
        'dob': patient?.dob,
        'gender': patient?.gender,
        'heightCm': patient?.heightCm,
        'weightKg': patient?.weightKg,
        'conditions': conditions.map((c) => c.name).toList(),
        'allergies': allergies.map((a) => a.substance).toList(),
        'conditionsDetail': conditions
            .map((c) => {'name': c.name, 'note': c.note})
            .toList(),
        'allergiesDetail': allergies
            .map((a) => {
                  'substance': a.substance,
                  'severity': a.severity,
                  'reaction': a.reaction,
                })
            .toList(),
      },
      'adherence': {
        'taken': adherence.taken,
        'total': adherence.total,
        'ratio': adherence.ratio,
      },
      'adherence30': {
        'taken': adherence30.taken,
        'total': adherence30.total,
        'ratio': adherence30.ratio,
      },
      'medications': meds.map((m) {
        final times = m.times.map((t) => t.time).toList()..sort();
        final schedule = m.times
            .map((t) => {'time': t.time, 'doseAmount': t.doseAmount})
            .toList()
          ..sort((a, b) =>
              (a['time'] as String).compareTo(b['time'] as String));
        return {
          'name': m.medication.name,
          'form': m.medication.form,
          'dosage': m.medication.dosage,
          'relationToMeal': m.medication.relationToMeal,
          'takeWith': m.medication.takeWith,
          'durationDays': m.medication.durationDays,
          'startDate': m.medication.startDate,
          'quantityTotal': m.medication.quantityTotal,
          'quantityRemaining': m.medication.quantityRemaining,
          'notes': m.medication.notes,
          'prescriptionId': m.medication.prescriptionId,
          'times': times,
          'schedule': schedule,
        };
      }).toList(),
      'prescriptions': prescriptionPayload,
      'appointments': upcoming
          .map((a) => {'type': a.type, 'date': a.date, 'note': a.note})
          .toList(),
      'history': history
          .map((d) => {
                'date': d.date,
                'taken': d.taken,
                'total': d.total,
                'doses': d.doses
                    .map((dose) => {
                          'name': dose.medicationName,
                          'time': dose.time,
                          'status': doseStatusToString(dose.status),
                          'takenAt': dose.takenAt,
                        })
                    .toList(),
              })
          .toList(),
    };
  }

  /// Pushes the latest snapshot to the doctor backend. No-op if not linked.
  Future<bool> syncToDoctor(int patientId) async {
    final pairCode = await settings.get(SettingsKeys.doctorPairCode);
    if (pairCode == null || pairCode.isEmpty) return false;

    try {
      final snapshot = await buildSnapshot(patientId);
      final res = await _client
          .post(
            Uri.parse('$apiBase/sync'),
            headers: const {
              'Content-Type': 'application/json',
              'bypass-tunnel-reminder': 'true',
            },
            body: jsonEncode({'pairCode': pairCode, 'snapshot': snapshot}),
          )
          .timeout(requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
