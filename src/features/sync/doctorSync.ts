/**
 * Doctor sync: links a patient to a doctor via a pairing code and pushes an
 * anonymized adherence snapshot to the backend so the doctor can monitor
 * medication adherence from the web dashboard.
 */
import { SCAN_API_URL } from '@/features/scan/aiScanner';
import { getSetting, setSetting, SettingsKeys } from '@/db/repositories/settings';
import { getPatient, listConditions, listAllergies } from '@/db/repositories/patients';
import { listActiveMedicationsWithSchedule } from '@/db/repositories/prescriptions';
import { getAdherence, getDoseHistory } from '@/db/repositories/doses';
import { ageFromDob } from '@/lib/date';

const API_BASE = SCAN_API_URL.replace(/\/scan-prescription\/?$/, '');
const REQUEST_TIMEOUT_MS = 20_000;

export interface DoctorLink {
  pairCode: string;
  doctorName: string;
}

async function withTimeout<T>(fn: (signal: AbortSignal) => Promise<T>): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fn(controller.signal);
  } finally {
    clearTimeout(timer);
  }
}

export async function getDoctorLink(): Promise<DoctorLink | null> {
  const pairCode = await getSetting(SettingsKeys.doctorPairCode);
  if (!pairCode) return null;
  return { pairCode, doctorName: (await getSetting(SettingsKeys.doctorName)) ?? '' };
}

export type PairError = 'invalid_code' | 'network';

/** Validates a pairing code with the backend and stores the link locally. */
export async function pairWithDoctor(
  code: string,
): Promise<{ ok: true; doctorName: string } | { ok: false; error: PairError }> {
  const clean = code.trim().toUpperCase();
  try {
    const res = await withTimeout((signal) =>
      fetch(`${API_BASE}/pair/${encodeURIComponent(clean)}`, {
        headers: { 'bypass-tunnel-reminder': 'true' },
        signal,
      }),
    );
    if (res.status === 404) return { ok: false, error: 'invalid_code' };
    if (!res.ok) return { ok: false, error: 'network' };
    const data = (await res.json()) as { ok: boolean; doctorName?: string };
    if (!data.ok) return { ok: false, error: 'invalid_code' };
    await setSetting(SettingsKeys.doctorPairCode, clean);
    await setSetting(SettingsKeys.doctorName, data.doctorName ?? '');
    return { ok: true, doctorName: data.doctorName ?? '' };
  } catch {
    return { ok: false, error: 'network' };
  }
}

export async function unlinkDoctor(): Promise<void> {
  await setSetting(SettingsKeys.doctorPairCode, '');
  await setSetting(SettingsKeys.doctorName, '');
}

async function buildSnapshot(patientId: number) {
  const patient = await getPatient(patientId);
  const conditions = await listConditions(patientId);
  const allergies = await listAllergies(patientId);
  const adherence = await getAdherence(patientId, 7);
  const meds = await listActiveMedicationsWithSchedule(patientId);
  const history = await getDoseHistory(patientId, 14);

  return {
    patient: {
      name: patient?.fullName ?? '',
      age: ageFromDob(patient?.dob),
      gender: patient?.gender ?? null,
      heightCm: patient?.heightCm ?? null,
      weightKg: patient?.weightKg ?? null,
      conditions: conditions.map((c) => c.name),
      allergies: allergies.map((a) => a.substance),
    },
    adherence: { taken: adherence.taken, total: adherence.total, ratio: adherence.ratio },
    medications: meds.map(({ medication, times }) => ({
      name: medication.name,
      dosage: medication.dosage,
      times: times.map((t) => t.time).sort(),
    })),
    history: history.map((d) => ({ date: d.date, taken: d.taken, total: d.total })),
  };
}

/** Pushes the latest snapshot to the doctor backend. No-op if not linked. */
export async function syncToDoctor(patientId: number): Promise<boolean> {
  const pairCode = await getSetting(SettingsKeys.doctorPairCode);
  if (!pairCode) return false;
  try {
    const snapshot = await buildSnapshot(patientId);
    const res = await withTimeout((signal) =>
      fetch(`${API_BASE}/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true' },
        body: JSON.stringify({ pairCode, snapshot }),
        signal,
      }),
    );
    return res.ok;
  } catch {
    return false;
  }
}
