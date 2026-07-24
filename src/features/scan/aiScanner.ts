/**
 * Sends a prescription image to the backend proxy, which calls Claude vision
 * and returns structured medication data. The Anthropic API key lives only on
 * the server — never in the app bundle.
 */

const DEFAULT_API_URL = 'https://medremind-backend-production.up.railway.app/api/scan-prescription';

// EXPO_PUBLIC_ vars are inlined by Metro at bundle time. Set in .env.
const API_URL = process.env.EXPO_PUBLIC_SCAN_API_URL || DEFAULT_API_URL;

const REQUEST_TIMEOUT_MS = 45_000;

export interface ScannedMedication {
  name: string;
  form?: string;
  dosage?: string;
  frequencyPerDay?: number;
  times?: string[];
  relationToMeal?: string;
  takeWith?: string;
  durationDays?: number;
  quantityTotal?: number;
  notes?: string;
}

export type ScanErrorCode = 'network' | 'server' | 'timeout';

export interface ScanResult {
  ok: boolean;
  error?: ScanErrorCode;
  doctorName?: string;
  clinic?: string;
  issuedDate?: string;
  rawText?: string;
  medications: ScannedMedication[];
}

export async function scanPrescriptionImage(
  imageBase64: string,
  mediaType = 'image/jpeg',
): Promise<ScanResult> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true' },
      body: JSON.stringify({ imageBase64, mediaType }),
      signal: controller.signal,
    });

    if (!res.ok) {
      return { ok: false, error: 'server', medications: [] };
    }

    const data = (await res.json()) as ScanResult;
    return {
      ok: true,
      doctorName: data.doctorName ?? '',
      clinic: data.clinic ?? '',
      issuedDate: data.issuedDate ?? '',
      rawText: data.rawText ?? '',
      medications: Array.isArray(data.medications) ? data.medications : [],
    };
  } catch (err) {
    const isAbort = err instanceof Error && err.name === 'AbortError';
    return { ok: false, error: isAbort ? 'timeout' : 'network', medications: [] };
  } finally {
    clearTimeout(timer);
  }
}

export { API_URL as SCAN_API_URL };
