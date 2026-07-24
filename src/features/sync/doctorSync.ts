/**
 * Doctor sync: links a patient to a doctor via a pairing code and pushes an
 * anonymized adherence snapshot to the backend so the doctor can monitor
 * medication adherence from the web dashboard.
 */
import { SCAN_API_URL } from '@/features/scan/aiScanner';
import { getSetting, setSetting, SettingsKeys } from '@/db/repositories/settings';
import { getPatient, listConditions, listAllergies } from '@/db/repositories/patients';
import {
  listActiveMedicationsWithSchedule,
  listPrescriptions,
  listMedications,
} from '@/db/repositories/prescriptions';
import { getAdherence, getDoseHistory } from '@/db/repositories/doses';
import { listUpcomingAppointments } from '@/db/repositories/appointments';
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
  const adherence30 = await getAdherence(patientId, 30);
  const meds = await listActiveMedicationsWithSchedule(patientId);
  const history = await getDoseHistory(patientId, 30);
  const prescriptionList = await listPrescriptions(patientId);
  const appointments = await listUpcomingAppointments(patientId);

  const prescriptions = await Promise.all(
    prescriptionList.map(async (p) => ({
      id: p.id,
      doctorName: p.doctorName,
      clinic: p.clinic,
      issuedDate: p.issuedDate,
      status: p.status,
      notes: p.notes,
      createdAt: p.createdAt,
      medicationCount: (await listMedications(p.id)).length,
    })),
  );

  return {
    patient: {
      name: patient?.fullName ?? '',
      age: ageFromDob(patient?.dob),
      dob: patient?.dob ?? null,
      gender: patient?.gender ?? null,
      heightCm: patient?.heightCm ?? null,
      weightKg: patient?.weightKg ?? null,
      conditions: conditions.map((c) => c.name),
      allergies: allergies.map((a) => a.substance),
      conditionsDetail: conditions.map((c) => ({ name: c.name, note: c.note })),
      allergiesDetail: allergies.map((a) => ({
        substance: a.substance,
        severity: a.severity,
        reaction: a.reaction,
      })),
    },
    adherence: { taken: adherence.taken, total: adherence.total, ratio: adherence.ratio },
    adherence30: { taken: adherence30.taken, total: adherence30.total, ratio: adherence30.ratio },
    medications: meds.map(({ medication, times }) => ({
      name: medication.name,
      form: medication.form,
      dosage: medication.dosage,
      relationToMeal: medication.relationToMeal,
      takeWith: medication.takeWith,
      durationDays: medication.durationDays,
      startDate: medication.startDate,
      quantityTotal: medication.quantityTotal,
      quantityRemaining: medication.quantityRemaining,
      notes: medication.notes,
      prescriptionId: medication.prescriptionId,
      times: times.map((t) => t.time).sort(),
      schedule: times
        .map((t) => ({ time: t.time, doseAmount: t.doseAmount }))
        .sort((a, b) => a.time.localeCompare(b.time)),
    })),
    prescriptions,
    appointments: appointments.map((a) => ({ type: a.type, date: a.date, note: a.note })),
    history: history.map((d) => ({
      date: d.date,
      taken: d.taken,
      total: d.total,
      doses: d.doses.map((dose) => ({
        name: dose.medicationName,
        time: dose.time,
        status: dose.status,
        takenAt: dose.takenAt,
      })),
    })),
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
