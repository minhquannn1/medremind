import { eq, isNull } from 'drizzle-orm';
import { db } from '../client';
import {
  patients,
  medicalConditions,
  allergies,
  type NewPatient,
  type Patient,
} from '../schema';
import { nowIso } from '@/lib/date';

export async function createPatient(
  data: Omit<NewPatient, 'id' | 'createdAt'>,
): Promise<number> {
  const res = await db
    .insert(patients)
    .values({ ...data, createdAt: nowIso() })
    .returning({ id: patients.id });
  return res[0].id;
}

export async function getPatient(id: number): Promise<Patient | null> {
  const rows = await db.select().from(patients).where(eq(patients.id, id)).limit(1);
  return rows[0] ?? null;
}

/** The local patient profile owned by a given server account, if any. */
export async function getPatientByAccount(accountUserId: number): Promise<Patient | null> {
  const rows = await db
    .select()
    .from(patients)
    .where(eq(patients.accountUserId, accountUserId))
    .limit(1);
  return rows[0] ?? null;
}

/**
 * A patient profile created before accounts existed (no owner). Used once, at
 * first sign-up, to let the new account adopt existing on-device data.
 */
export async function claimOrphanPatient(accountUserId: number, accountEmail: string): Promise<Patient | null> {
  const orphan = (
    await db.select().from(patients).where(isNull(patients.accountUserId)).limit(1)
  )[0];
  if (!orphan) return null;
  await db
    .update(patients)
    .set({ accountUserId, accountEmail })
    .where(eq(patients.id, orphan.id));
  return { ...orphan, accountUserId, accountEmail };
}

export async function updatePatient(
  id: number,
  data: Partial<Omit<NewPatient, 'id' | 'createdAt'>>,
): Promise<void> {
  await db.update(patients).set(data).where(eq(patients.id, id));
}

// Medical conditions
export async function listConditions(patientId: number) {
  return db
    .select()
    .from(medicalConditions)
    .where(eq(medicalConditions.patientId, patientId));
}

export async function addCondition(patientId: number, name: string, note?: string) {
  await db
    .insert(medicalConditions)
    .values({ patientId, name, note, createdAt: nowIso() });
}

export async function removeCondition(id: number) {
  await db.delete(medicalConditions).where(eq(medicalConditions.id, id));
}

// Allergies
export async function listAllergies(patientId: number) {
  return db.select().from(allergies).where(eq(allergies.patientId, patientId));
}

export async function addAllergy(
  patientId: number,
  substance: string,
  severity?: string,
  reaction?: string,
) {
  await db
    .insert(allergies)
    .values({ patientId, substance, severity, reaction, createdAt: nowIso() });
}

export async function removeAllergy(id: number) {
  await db.delete(allergies).where(eq(allergies.id, id));
}
