/// Typed row models mirroring the SQLite schema.
/// Ported 1:1 from the React Native `src/db/schema.ts` (Drizzle definitions).
///
/// Every model round-trips through `fromMap` / `toMap` using the exact
/// snake_case column names the DDL creates, so the two apps read and write
/// byte-identical databases and cloud backups.
library;

class Patient {
  final int id;
  final String fullName;
  final String? dob; // ISO date YYYY-MM-DD
  final String? gender; // male | female | other
  final double? heightCm;
  final double? weightKg;
  final int? accountUserId; // server account id this profile belongs to
  final String? accountEmail;
  final String createdAt;

  const Patient({
    required this.id,
    required this.fullName,
    this.dob,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.accountUserId,
    this.accountEmail,
    required this.createdAt,
  });

  factory Patient.fromMap(Map<String, Object?> m) => Patient(
        id: m['id'] as int,
        fullName: m['full_name'] as String,
        dob: m['dob'] as String?,
        gender: m['gender'] as String?,
        heightCm: (m['height_cm'] as num?)?.toDouble(),
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        accountUserId: m['account_user_id'] as int?,
        accountEmail: m['account_email'] as String?,
        createdAt: m['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'full_name': fullName,
        'dob': dob,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'account_user_id': accountUserId,
        'account_email': accountEmail,
        'created_at': createdAt,
      };

  /// Cloud-backup JSON. The RN app serialises Drizzle rows, which use
  /// camelCase property names — the backup blob on the server is shared
  /// between both apps, so these keys must stay camelCase, unlike [toMap].
  Map<String, Object?> toJson() => {
        'id': id,
        'fullName': fullName,
        'dob': dob,
        'gender': gender,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'accountUserId': accountUserId,
        'accountEmail': accountEmail,
        'createdAt': createdAt,
      };

  factory Patient.fromJson(Map<String, Object?> j) => Patient(
        id: (j['id'] as num?)?.toInt() ?? 0,
        fullName: (j['fullName'] as String?) ?? '',
        dob: j['dob'] as String?,
        gender: j['gender'] as String?,
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        accountUserId: (j['accountUserId'] as num?)?.toInt(),
        accountEmail: j['accountEmail'] as String?,
        createdAt: (j['createdAt'] as String?) ?? '',
      );

  Patient copyWith({
    String? fullName,
    String? dob,
    String? gender,
    double? heightCm,
    double? weightKg,
    int? accountUserId,
    String? accountEmail,
  }) =>
      Patient(
        id: id,
        fullName: fullName ?? this.fullName,
        dob: dob ?? this.dob,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        accountUserId: accountUserId ?? this.accountUserId,
        accountEmail: accountEmail ?? this.accountEmail,
        createdAt: createdAt,
      );
}

class MedicalCondition {
  final int id;
  final int patientId;
  final String name;
  final String? note;
  final String createdAt;

  const MedicalCondition({
    required this.id,
    required this.patientId,
    required this.name,
    this.note,
    required this.createdAt,
  });

  factory MedicalCondition.fromMap(Map<String, Object?> m) => MedicalCondition(
        id: m['id'] as int,
        patientId: m['patient_id'] as int,
        name: m['name'] as String,
        note: m['note'] as String?,
        createdAt: m['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'patient_id': patientId,
        'name': name,
        'note': note,
        'created_at': createdAt,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'name': name,
        'note': note,
        'createdAt': createdAt,
      };

  factory MedicalCondition.fromJson(Map<String, Object?> j) => MedicalCondition(
        id: (j['id'] as num?)?.toInt() ?? 0,
        patientId: (j['patientId'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        note: j['note'] as String?,
        createdAt: (j['createdAt'] as String?) ?? '',
      );
}

class Allergy {
  final int id;
  final int patientId;
  final String substance;
  final String? severity; // mild | moderate | severe
  final String? reaction;
  final String createdAt;

  const Allergy({
    required this.id,
    required this.patientId,
    required this.substance,
    this.severity,
    this.reaction,
    required this.createdAt,
  });

  factory Allergy.fromMap(Map<String, Object?> m) => Allergy(
        id: m['id'] as int,
        patientId: m['patient_id'] as int,
        substance: m['substance'] as String,
        severity: m['severity'] as String?,
        reaction: m['reaction'] as String?,
        createdAt: m['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'patient_id': patientId,
        'substance': substance,
        'severity': severity,
        'reaction': reaction,
        'created_at': createdAt,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'substance': substance,
        'severity': severity,
        'reaction': reaction,
        'createdAt': createdAt,
      };

  factory Allergy.fromJson(Map<String, Object?> j) => Allergy(
        id: (j['id'] as num?)?.toInt() ?? 0,
        patientId: (j['patientId'] as num?)?.toInt() ?? 0,
        substance: (j['substance'] as String?) ?? '',
        severity: j['severity'] as String?,
        reaction: j['reaction'] as String?,
        createdAt: (j['createdAt'] as String?) ?? '',
      );
}

class Prescription {
  final int id;
  final int patientId;
  final String? doctorName;
  final String? clinic;
  final String? issuedDate; // ISO date
  final String? notes;
  final String? imageUri;
  final String status; // active | completed
  final String createdAt;

  const Prescription({
    required this.id,
    required this.patientId,
    this.doctorName,
    this.clinic,
    this.issuedDate,
    this.notes,
    this.imageUri,
    this.status = 'active',
    required this.createdAt,
  });

  factory Prescription.fromMap(Map<String, Object?> m) => Prescription(
        id: m['id'] as int,
        patientId: m['patient_id'] as int,
        doctorName: m['doctor_name'] as String?,
        clinic: m['clinic'] as String?,
        issuedDate: m['issued_date'] as String?,
        notes: m['notes'] as String?,
        imageUri: m['image_uri'] as String?,
        status: (m['status'] as String?) ?? 'active',
        createdAt: m['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'patient_id': patientId,
        'doctor_name': doctorName,
        'clinic': clinic,
        'issued_date': issuedDate,
        'notes': notes,
        'image_uri': imageUri,
        'status': status,
        'created_at': createdAt,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'doctorName': doctorName,
        'clinic': clinic,
        'issuedDate': issuedDate,
        'notes': notes,
        'imageUri': imageUri,
        'status': status,
        'createdAt': createdAt,
      };

  factory Prescription.fromJson(Map<String, Object?> j) => Prescription(
        id: (j['id'] as num?)?.toInt() ?? 0,
        patientId: (j['patientId'] as num?)?.toInt() ?? 0,
        doctorName: j['doctorName'] as String?,
        clinic: j['clinic'] as String?,
        issuedDate: j['issuedDate'] as String?,
        notes: j['notes'] as String?,
        imageUri: j['imageUri'] as String?,
        status: (j['status'] as String?) ?? 'active',
        createdAt: (j['createdAt'] as String?) ?? '',
      );
}

class Medication {
  final int id;
  final int prescriptionId;
  final String name;
  final String? form; // tablet | capsule | syrup | ...
  final String? dosage; // free text "1 viên"
  final String? relationToMeal; // before | after | with | anytime
  final String? takeWith;
  final int? durationDays;
  final String? startDate; // ISO date
  final double? quantityTotal;
  final double? quantityRemaining;
  final String? notes;
  final String? explanation; // AI plain-language "what this medicine is for"
  final String? explanationLang; // language the explanation was generated in
  final String? imageUri; // user photo of the medicine, device-local
  final String createdAt;

  const Medication({
    required this.id,
    required this.prescriptionId,
    required this.name,
    this.form,
    this.dosage,
    this.relationToMeal,
    this.takeWith,
    this.durationDays,
    this.startDate,
    this.quantityTotal,
    this.quantityRemaining,
    this.notes,
    this.explanation,
    this.explanationLang,
    this.imageUri,
    required this.createdAt,
  });

  factory Medication.fromMap(Map<String, Object?> m) => Medication(
        id: m['id'] as int,
        prescriptionId: m['prescription_id'] as int,
        name: m['name'] as String,
        form: m['form'] as String?,
        dosage: m['dosage'] as String?,
        relationToMeal: m['relation_to_meal'] as String?,
        takeWith: m['take_with'] as String?,
        durationDays: (m['duration_days'] as num?)?.toInt(),
        startDate: m['start_date'] as String?,
        quantityTotal: (m['quantity_total'] as num?)?.toDouble(),
        quantityRemaining: (m['quantity_remaining'] as num?)?.toDouble(),
        notes: m['notes'] as String?,
        explanation: m['explanation'] as String?,
        explanationLang: m['explanation_lang'] as String?,
        imageUri: m['image_uri'] as String?,
        createdAt: m['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'prescription_id': prescriptionId,
        'name': name,
        'form': form,
        'dosage': dosage,
        'relation_to_meal': relationToMeal,
        'take_with': takeWith,
        'duration_days': durationDays,
        'start_date': startDate,
        'quantity_total': quantityTotal,
        'quantity_remaining': quantityRemaining,
        'notes': notes,
        'explanation': explanation,
        'explanation_lang': explanationLang,
        'image_uri': imageUri,
        'created_at': createdAt,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'prescriptionId': prescriptionId,
        'name': name,
        'form': form,
        'dosage': dosage,
        'relationToMeal': relationToMeal,
        'takeWith': takeWith,
        'durationDays': durationDays,
        'startDate': startDate,
        'quantityTotal': quantityTotal,
        'quantityRemaining': quantityRemaining,
        'notes': notes,
        'explanation': explanation,
        'explanationLang': explanationLang,
        'imageUri': imageUri,
        'createdAt': createdAt,
      };

  factory Medication.fromJson(Map<String, Object?> j) => Medication(
        id: (j['id'] as num?)?.toInt() ?? 0,
        prescriptionId: (j['prescriptionId'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        form: j['form'] as String?,
        dosage: j['dosage'] as String?,
        relationToMeal: j['relationToMeal'] as String?,
        takeWith: j['takeWith'] as String?,
        durationDays: (j['durationDays'] as num?)?.toInt(),
        startDate: j['startDate'] as String?,
        quantityTotal: (j['quantityTotal'] as num?)?.toDouble(),
        quantityRemaining: (j['quantityRemaining'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
        explanation: j['explanation'] as String?,
        explanationLang: j['explanationLang'] as String?,
        imageUri: j['imageUri'] as String?,
        createdAt: (j['createdAt'] as String?) ?? '',
      );
}

class ScheduleTime {
  final int id;
  final int medicationId;
  final String time; // HH:mm (24h)
  final double doseAmount;

  const ScheduleTime({
    required this.id,
    required this.medicationId,
    required this.time,
    this.doseAmount = 1,
  });

  factory ScheduleTime.fromMap(Map<String, Object?> m) => ScheduleTime(
        id: m['id'] as int,
        medicationId: m['medication_id'] as int,
        time: m['time'] as String,
        doseAmount: (m['dose_amount'] as num?)?.toDouble() ?? 1,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'medication_id': medicationId,
        'time': time,
        'dose_amount': doseAmount,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'medicationId': medicationId,
        'time': time,
        'doseAmount': doseAmount,
      };

  factory ScheduleTime.fromJson(Map<String, Object?> j) => ScheduleTime(
        id: (j['id'] as num?)?.toInt() ?? 0,
        medicationId: (j['medicationId'] as num?)?.toInt() ?? 0,
        time: (j['time'] as String?) ?? '',
        doseAmount: (j['doseAmount'] as num?)?.toDouble() ?? 1,
      );
}

class DoseLog {
  final int id;
  final int medicationId;
  final int? scheduleTimeId;
  final String scheduledAt; // ISO datetime
  final String status; // pending | taken | skipped | missed
  final String? takenAt;
  final double? quantity;

  const DoseLog({
    required this.id,
    required this.medicationId,
    this.scheduleTimeId,
    required this.scheduledAt,
    this.status = 'pending',
    this.takenAt,
    this.quantity,
  });

  factory DoseLog.fromMap(Map<String, Object?> m) => DoseLog(
        id: m['id'] as int,
        medicationId: m['medication_id'] as int,
        scheduleTimeId: (m['schedule_time_id'] as num?)?.toInt(),
        scheduledAt: m['scheduled_at'] as String,
        status: (m['status'] as String?) ?? 'pending',
        takenAt: m['taken_at'] as String?,
        quantity: (m['quantity'] as num?)?.toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'medication_id': medicationId,
        'schedule_time_id': scheduleTimeId,
        'scheduled_at': scheduledAt,
        'status': status,
        'taken_at': takenAt,
        'quantity': quantity,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'medicationId': medicationId,
        'scheduleTimeId': scheduleTimeId,
        'scheduledAt': scheduledAt,
        'status': status,
        'takenAt': takenAt,
        'quantity': quantity,
      };

  factory DoseLog.fromJson(Map<String, Object?> j) => DoseLog(
        id: (j['id'] as num?)?.toInt() ?? 0,
        medicationId: (j['medicationId'] as num?)?.toInt() ?? 0,
        scheduleTimeId: (j['scheduleTimeId'] as num?)?.toInt(),
        scheduledAt: (j['scheduledAt'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'pending',
        takenAt: j['takenAt'] as String?,
        quantity: (j['quantity'] as num?)?.toDouble(),
      );
}

class Appointment {
  final int id;
  final int patientId;
  final String type; // revisit | refill
  final String date; // ISO datetime
  final String? note;
  final String? notificationId;
  final String createdAt;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.type,
    required this.date,
    this.note,
    this.notificationId,
    required this.createdAt,
  });

  factory Appointment.fromMap(Map<String, Object?> m) => Appointment(
        id: m['id'] as int,
        patientId: m['patient_id'] as int,
        type: m['type'] as String,
        date: m['date'] as String,
        note: m['note'] as String?,
        notificationId: m['notification_id'] as String?,
        createdAt: m['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'patient_id': patientId,
        'type': type,
        'date': date,
        'note': note,
        'notification_id': notificationId,
        'created_at': createdAt,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'type': type,
        'date': date,
        'note': note,
        'notificationId': notificationId,
        'createdAt': createdAt,
      };

  factory Appointment.fromJson(Map<String, Object?> j) => Appointment(
        id: (j['id'] as num?)?.toInt() ?? 0,
        patientId: (j['patientId'] as num?)?.toInt() ?? 0,
        type: (j['type'] as String?) ?? 'revisit',
        date: (j['date'] as String?) ?? '',
        note: j['note'] as String?,
        notificationId: j['notificationId'] as String?,
        createdAt: (j['createdAt'] as String?) ?? '',
      );
}
