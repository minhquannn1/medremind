import { eq } from 'drizzle-orm';
import { db } from '../client';
import { settings } from '../schema';

export async function getSetting(key: string): Promise<string | null> {
  const rows = await db.select().from(settings).where(eq(settings.key, key)).limit(1);
  return rows[0]?.value ?? null;
}

export async function setSetting(key: string, value: string): Promise<void> {
  await db
    .insert(settings)
    .values({ key, value })
    .onConflictDoUpdate({ target: settings.key, set: { value } });
}

export const SettingsKeys = {
  language: 'language',
  activePatientId: 'active_patient_id',
  onboarded: 'onboarded',
  reminderSound: 'reminder_sound',
  reminderVibration: 'reminder_vibration',
  doctorPairCode: 'doctor_pair_code',
  doctorName: 'doctor_name',
  authToken: 'auth_token',
  accountUserId: 'account_user_id',
  accountEmail: 'account_email',
  accountName: 'account_name',
} as const;

export async function getBoolSetting(key: string, fallback: boolean): Promise<boolean> {
  const v = await getSetting(key);
  if (v == null) return fallback;
  return v === 'true';
}
