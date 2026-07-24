import { eq, desc, inArray } from 'drizzle-orm';
import { db } from '../client';
import {
  prescriptions,
  medications,
  scheduleTimes,
  type NewPrescription,
  type NewMedication,
  type Prescription,
  type Medication,
  type ScheduleTime,
} from '../schema';
import { nowIso } from '@/lib/date';

export interface MedicationInput {
  name: string;
  form?: string | null;
  dosage?: string | null;
  relationToMeal?: string | null;
  takeWith?: string | null;
  durationDays?: number | null;
  startDate?: string | null;
  quantityTotal?: number | null;
  notes?: string | null;
  times: { time: string; doseAmount: number }[];
}

export interface PrescriptionInput {
  patientId: number;
  doctorName?: string | null;
  clinic?: string | null;
  issuedDate?: string | null;
  notes?: string | null;
  imageUri?: string | null;
  medications: MedicationInput[];
}

export async function createPrescription(input: PrescriptionInput): Promise<number> {
  const res = await db
    .insert(prescriptions)
    .values({
      patientId: input.patientId,
      doctorName: input.doctorName,
      clinic: input.clinic,
      issuedDate: input.issuedDate,
      notes: input.notes,
      imageUri: input.imageUri,
      status: 'active',
      createdAt: nowIso(),
    })
    .returning({ id: prescriptions.id });
  const prescriptionId = res[0].id;

  for (const med of input.medications) {
    await addMedicationToPrescription(prescriptionId, med);
  }
  return prescriptionId;
}

export async function addMedicationToPrescription(
  prescriptionId: number,
  med: MedicationInput,
): Promise<number> {
  const medRes = await db
    .insert(medications)
    .values({
      prescriptionId,
      name: med.name,
      form: med.form,
      dosage: med.dosage,
      relationToMeal: med.relationToMeal,
      takeWith: med.takeWith,
      durationDays: med.durationDays,
      startDate: med.startDate,
      quantityTotal: med.quantityTotal,
      quantityRemaining: med.quantityTotal,
      notes: med.notes,
      createdAt: nowIso(),
    })
    .returning({ id: medications.id });
  const medicationId = medRes[0].id;

  for (const t of med.times) {
    await db
      .insert(scheduleTimes)
      .values({ medicationId, time: t.time, doseAmount: t.doseAmount });
  }
  return medicationId;
}

export async function listPrescriptions(patientId: number): Promise<Prescription[]> {
  return db
    .select()
    .from(prescriptions)
    .where(eq(prescriptions.patientId, patientId))
    .orderBy(desc(prescriptions.createdAt));
}

export async function getPrescription(id: number): Promise<Prescription | null> {
  const rows = await db.select().from(prescriptions).where(eq(prescriptions.id, id)).limit(1);
  return rows[0] ?? null;
}

export async function updatePrescriptionStatus(id: number, status: 'active' | 'completed') {
  await db.update(prescriptions).set({ status }).where(eq(prescriptions.id, id));
}

export async function deletePrescription(id: number): Promise<void> {
  const meds = await db
    .select({ id: medications.id })
    .from(medications)
    .where(eq(medications.prescriptionId, id));
  const medIds = meds.map((m) => m.id);
  if (medIds.length) {
    await db.delete(scheduleTimes).where(inArray(scheduleTimes.medicationId, medIds));
    await db.delete(medications).where(eq(medications.prescriptionId, id));
  }
  await db.delete(prescriptions).where(eq(prescriptions.id, id));
}

export async function listMedications(prescriptionId: number): Promise<Medication[]> {
  return db.select().from(medications).where(eq(medications.prescriptionId, prescriptionId));
}

export async function getMedication(id: number): Promise<Medication | null> {
  const rows = await db.select().from(medications).where(eq(medications.id, id)).limit(1);
  return rows[0] ?? null;
}

export async function listScheduleTimes(medicationId: number): Promise<ScheduleTime[]> {
  return db.select().from(scheduleTimes).where(eq(scheduleTimes.medicationId, medicationId));
}

export async function updateScheduleTime(id: number, time: string): Promise<void> {
  await db.update(scheduleTimes).set({ time }).where(eq(scheduleTimes.id, id));
}

export async function updateMedicationExplanation(
  medicationId: number,
  explanation: string,
  lang: string,
): Promise<void> {
  await db
    .update(medications)
    .set({ explanation, explanationLang: lang })
    .where(eq(medications.id, medicationId));
}

export async function adjustMedicationStock(medicationId: number, delta: number): Promise<void> {
  const med = await getMedication(medicationId);
  if (!med || med.quantityRemaining == null) return;
  const next = Math.max(0, med.quantityRemaining + delta);
  await db
    .update(medications)
    .set({ quantityRemaining: next })
    .where(eq(medications.id, medicationId));
}

/** All active medications for a patient, with their schedule times. */
export async function listActiveMedicationsWithSchedule(patientId: number) {
  const activePrescriptions = await db
    .select({ id: prescriptions.id })
    .from(prescriptions)
    .where(eq(prescriptions.patientId, patientId));
  const presIds = activePrescriptions.map((p) => p.id);
  if (!presIds.length) return [];

  const meds = await db
    .select()
    .from(medications)
    .where(inArray(medications.prescriptionId, presIds));
  if (!meds.length) return [];

  const medIds = meds.map((m) => m.id);
  const times = await db
    .select()
    .from(scheduleTimes)
    .where(inArray(scheduleTimes.medicationId, medIds));

  return meds.map((med) => ({
    medication: med,
    times: times.filter((t) => t.medicationId === med.id),
  }));
}
