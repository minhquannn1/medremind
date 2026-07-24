import { eq, inArray } from 'drizzle-orm';
import { db } from '../client';
import {
  patients,
  medicalConditions,
  allergies,
  prescriptions,
  medications,
  scheduleTimes,
  doseLogs,
  appointments,
  type Patient,
  type MedicalCondition,
  type Allergy,
  type Prescription,
  type Medication,
  type ScheduleTime,
  type DoseLog,
  type Appointment,
} from '../schema';
import { getSetting, setSetting, SettingsKeys } from './settings';

export const BACKUP_VERSION = 1;

export interface PatientDataExport {
  version: number;
  exportedAt: string;
  patient: Patient;
  conditions: MedicalCondition[];
  allergies: Allergy[];
  prescriptions: Prescription[];
  medications: Medication[];
  scheduleTimes: ScheduleTime[];
  doseLogs: DoseLog[];
  appointments: Appointment[];
  settings: {
    doctorPairCode: string | null;
    doctorName: string | null;
    reminderSound: string | null;
    reminderVibration: string | null;
  };
}

/** Full export of everything the app stores for one patient profile. */
export async function exportPatientData(patientId: number): Promise<PatientDataExport | null> {
  const patientRows = await db.select().from(patients).where(eq(patients.id, patientId)).limit(1);
  const patient = patientRows[0];
  if (!patient) return null;

  const conditionRows = await db
    .select()
    .from(medicalConditions)
    .where(eq(medicalConditions.patientId, patientId));
  const allergyRows = await db.select().from(allergies).where(eq(allergies.patientId, patientId));
  const prescriptionRows = await db
    .select()
    .from(prescriptions)
    .where(eq(prescriptions.patientId, patientId));
  const appointmentRows = await db
    .select()
    .from(appointments)
    .where(eq(appointments.patientId, patientId));

  const presIds = prescriptionRows.map((p) => p.id);
  const medicationRows = presIds.length
    ? await db.select().from(medications).where(inArray(medications.prescriptionId, presIds))
    : [];
  const medIds = medicationRows.map((m) => m.id);
  const timeRows = medIds.length
    ? await db.select().from(scheduleTimes).where(inArray(scheduleTimes.medicationId, medIds))
    : [];
  const doseRows = medIds.length
    ? await db.select().from(doseLogs).where(inArray(doseLogs.medicationId, medIds))
    : [];

  return {
    version: BACKUP_VERSION,
    exportedAt: new Date().toISOString(),
    patient,
    conditions: conditionRows,
    allergies: allergyRows,
    prescriptions: prescriptionRows,
    medications: medicationRows,
    scheduleTimes: timeRows,
    doseLogs: doseRows,
    appointments: appointmentRows,
    settings: {
      doctorPairCode: await getSetting(SettingsKeys.doctorPairCode),
      doctorName: await getSetting(SettingsKeys.doctorName),
      reminderSound: await getSetting(SettingsKeys.reminderSound),
      reminderVibration: await getSetting(SettingsKeys.reminderVibration),
    },
  };
}

/**
 * Imports a full export into the local database, remapping all row ids
 * (the new device assigns fresh autoincrement ids). Intended for a fresh
 * sign-in where no local profile exists for the account yet.
 * Returns the new local patient id.
 */
export async function importPatientData(
  data: PatientDataExport,
  accountUserId: number,
  accountEmail: string,
): Promise<number> {
  const patientRes = await db
    .insert(patients)
    .values({
      fullName: data.patient.fullName,
      dob: data.patient.dob,
      gender: data.patient.gender,
      heightCm: data.patient.heightCm,
      weightKg: data.patient.weightKg,
      accountUserId,
      accountEmail,
      createdAt: data.patient.createdAt,
    })
    .returning({ id: patients.id });
  const patientId = patientRes[0].id;

  for (const c of data.conditions) {
    await db
      .insert(medicalConditions)
      .values({ patientId, name: c.name, note: c.note, createdAt: c.createdAt });
  }
  for (const a of data.allergies) {
    await db.insert(allergies).values({
      patientId,
      substance: a.substance,
      severity: a.severity,
      reaction: a.reaction,
      createdAt: a.createdAt,
    });
  }

  const presIdMap = new Map<number, number>();
  for (const p of data.prescriptions) {
    const res = await db
      .insert(prescriptions)
      .values({
        patientId,
        doctorName: p.doctorName,
        clinic: p.clinic,
        issuedDate: p.issuedDate,
        notes: p.notes,
        // Image files live outside the db and don't survive a device change.
        imageUri: null,
        status: p.status,
        createdAt: p.createdAt,
      })
      .returning({ id: prescriptions.id });
    presIdMap.set(p.id, res[0].id);
  }

  const medIdMap = new Map<number, number>();
  for (const m of data.medications) {
    const prescriptionId = presIdMap.get(m.prescriptionId);
    if (prescriptionId == null) continue;
    const res = await db
      .insert(medications)
      .values({
        prescriptionId,
        name: m.name,
        form: m.form,
        dosage: m.dosage,
        relationToMeal: m.relationToMeal,
        takeWith: m.takeWith,
        durationDays: m.durationDays,
        startDate: m.startDate,
        quantityTotal: m.quantityTotal,
        quantityRemaining: m.quantityRemaining,
        notes: m.notes,
        explanation: m.explanation,
        explanationLang: m.explanationLang,
        // Medicine photos are device-local files and don't survive a device change.
        imageUri: null,
        createdAt: m.createdAt,
      })
      .returning({ id: medications.id });
    medIdMap.set(m.id, res[0].id);
  }

  const timeIdMap = new Map<number, number>();
  for (const t of data.scheduleTimes) {
    const medicationId = medIdMap.get(t.medicationId);
    if (medicationId == null) continue;
    const res = await db
      .insert(scheduleTimes)
      .values({ medicationId, time: t.time, doseAmount: t.doseAmount })
      .returning({ id: scheduleTimes.id });
    timeIdMap.set(t.id, res[0].id);
  }

  for (const d of data.doseLogs) {
    const medicationId = medIdMap.get(d.medicationId);
    if (medicationId == null) continue;
    await db.insert(doseLogs).values({
      medicationId,
      scheduleTimeId: d.scheduleTimeId != null ? (timeIdMap.get(d.scheduleTimeId) ?? null) : null,
      scheduledAt: d.scheduledAt,
      status: d.status,
      takenAt: d.takenAt,
      quantity: d.quantity,
    });
  }

  for (const a of data.appointments) {
    await db.insert(appointments).values({
      patientId,
      type: a.type,
      date: a.date,
      note: a.note,
      // Notification ids are device-local; reminders are rescheduled after restore.
      notificationId: null,
      createdAt: a.createdAt,
    });
  }

  if (data.settings.doctorPairCode) {
    await setSetting(SettingsKeys.doctorPairCode, data.settings.doctorPairCode);
    await setSetting(SettingsKeys.doctorName, data.settings.doctorName ?? '');
  }
  if (data.settings.reminderSound != null) {
    await setSetting(SettingsKeys.reminderSound, data.settings.reminderSound);
  }
  if (data.settings.reminderVibration != null) {
    await setSetting(SettingsKeys.reminderVibration, data.settings.reminderVibration);
  }

  return patientId;
}
