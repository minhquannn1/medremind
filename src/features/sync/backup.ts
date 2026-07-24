/**
 * Cloud backup: uploads a full JSON export of the local database to the
 * backend (keyed by the signed-in account) and restores it on a new device.
 */
import { SCAN_API_URL } from '@/features/scan/aiScanner';
import { getSetting, SettingsKeys } from '@/db/repositories/settings';
import {
  exportPatientData,
  type PatientDataExport,
} from '@/db/repositories/backup';

const API_BASE = SCAN_API_URL.replace(/\/scan-prescription\/?$/, '');
const REQUEST_TIMEOUT_MS = 30_000;
const DEBOUNCE_MS = 5_000;

async function withTimeout<T>(fn: (signal: AbortSignal) => Promise<T>): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fn(controller.signal);
  } finally {
    clearTimeout(timer);
  }
}

/** Uploads a full export of the patient's data. No-op when signed out. */
export async function backupNow(patientId: number): Promise<boolean> {
  const token = await getSetting(SettingsKeys.authToken);
  if (!token) return false;
  const data = await exportPatientData(patientId);
  if (!data) return false;
  try {
    const res = await withTimeout((signal) =>
      fetch(`${API_BASE}/patient/backup`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'bypass-tunnel-reminder': 'true',
        },
        body: JSON.stringify({ data }),
        signal,
      }),
    );
    return res.ok;
  } catch {
    return false;
  }
}

let pendingBackup: ReturnType<typeof setTimeout> | null = null;

/**
 * Schedules a backup shortly after the current burst of data changes.
 * Fire-and-forget: failures are silent and retried on the next change.
 */
export function queueBackup(patientId: number): void {
  if (pendingBackup) clearTimeout(pendingBackup);
  pendingBackup = setTimeout(() => {
    pendingBackup = null;
    void backupNow(patientId);
  }, DEBOUNCE_MS);
}

/** Downloads the account's backup, or null when none exists / on error. */
export async function fetchServerBackup(token: string): Promise<PatientDataExport | null> {
  try {
    const res = await withTimeout((signal) =>
      fetch(`${API_BASE}/patient/backup`, {
        headers: { Authorization: `Bearer ${token}`, 'bypass-tunnel-reminder': 'true' },
        signal,
      }),
    );
    if (!res.ok) return null;
    const body = (await res.json()) as { ok?: boolean; data?: PatientDataExport | null };
    if (!body.ok || !body.data || typeof body.data !== 'object') return null;
    if (!body.data.patient || !Array.isArray(body.data.prescriptions)) return null;
    return body.data;
  } catch {
    return null;
  }
}
